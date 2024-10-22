package org.sippi;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.sippy.wrapper.parent.WrappedMethods;
import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.io.OutputStream;
import java.lang.reflect.InvocationTargetException;
import java.lang.reflect.Method;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.charset.StandardCharsets;
import java.util.Map;
import java.util.stream.Collectors;
import javax.ejb.EJB;
import javax.ejb.Singleton;
import org.jboss.netty.buffer.ChannelBuffer;
import org.jboss.netty.buffer.ChannelBuffers;
import org.jboss.netty.channel.*;
import org.jboss.netty.handler.codec.http.*;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

@Singleton
public class CustomServerHandler extends SimpleChannelUpstreamHandler {

  private static final Logger LOGGER = LoggerFactory.getLogger(CustomServerHandler.class);
  @EJB private RpcMethodHolder rpcMethodHolder;
  @EJB private WrappedMethods wrappedMethods;
  private final ObjectMapper objectMapper;

  public CustomServerHandler() {
    this.objectMapper = new ObjectMapper();
  }

  @Override
  public void messageReceived(ChannelHandlerContext ctx, MessageEvent e) {
    String requestUri = ((HttpRequest) e.getMessage()).getUri();

    switch (requestUri) {
      case "/hello":
        handleHelloEndpoint(e);
        break;
      case "/jsonrpc":
        handleJsonRpcEndpoint(e);
        break;
      default:
        handle404Response(e);
    }
  }

  private void handleJsonRpcEndpoint(MessageEvent e) {
    HttpResponse response = new DefaultHttpResponse(HttpVersion.HTTP_1_1, HttpResponseStatus.OK);
    String contentString = extractRequestContent((HttpRequest) e.getMessage());

    try {
      RpcRequest rpcRequest = objectMapper.readValue(contentString, RpcRequest.class);
      Map<String, Method> rpcMethods = rpcMethodHolder.getRpcMethods();
      String rpcMethodName = rpcRequest.getMethod();

      rpcMethods.entrySet().stream()
          .filter(entry -> rpcMethodName.equals(entry.getKey()))
          .findFirst()
          .ifPresentOrElse(
              entry -> invokeJavaAppMethod(entry.getValue(), response, rpcRequest),
              () -> invokePerlAppMethod(response, rpcMethodName, contentString));
    } catch (JsonProcessingException ex) {
      LOGGER.error("Failed to parse JSON request: {}", ex.getMessage());
      handleErrorResponse(response, HttpResponseStatus.BAD_REQUEST, "Invalid JSON format");
    }

    sendResponse(e, response);
  }

  private void invokeJavaAppMethod(Method method, HttpResponse response, RpcRequest rpcRequest) {
    try {
      Class<?>[] parameterTypes = method.getParameterTypes();

      if (parameterTypes.length > 1) {
        throw new IllegalArgumentException(
            "Method has more than one parameter, which is not supported.");
      }

      final Object result;
      if (parameterTypes.length == 0) {
        result = method.invoke(wrappedMethods);
      } else {
        Object params = rpcRequest.getParams();
        Object paramInstance = objectMapper.convertValue(params, parameterTypes[0]);
        result = method.invoke(wrappedMethods, paramInstance);
      }

      String jsonResponse = objectMapper.writeValueAsString(result);
      setJsonResponse(response, jsonResponse);
      LOGGER.info("Method result: {}", result);
    } catch (IllegalArgumentException ex) {
      LOGGER.error(
          "Invalid argument provided for method {}: {}", rpcRequest.getMethod(), ex.getMessage());
      handleErrorResponse(
          response,
          HttpResponseStatus.BAD_REQUEST,
          "Invalid arguments for method: " + rpcRequest.getMethod());

    } catch (IllegalAccessException ex) {
      LOGGER.error(
          "Illegal access when invoking method {}: {}", rpcRequest.getMethod(), ex.getMessage());
      handleErrorResponse(
          response,
          HttpResponseStatus.FORBIDDEN,
          "Illegal access to method: " + rpcRequest.getMethod());

    } catch (InvocationTargetException ex) {
      LOGGER.error("Exception thrown by method {}: {}", rpcRequest.getMethod(), ex.getMessage());
      handleErrorResponse(
          response,
          HttpResponseStatus.INTERNAL_SERVER_ERROR,
          "Error invoking method: " + rpcRequest.getMethod());

    } catch (JsonProcessingException ex) {
      LOGGER.error(
          "Failed to serialize method result to JSON for method {}: {}",
          rpcRequest.getMethod(),
          ex.getMessage());
      handleErrorResponse(
          response,
          HttpResponseStatus.INTERNAL_SERVER_ERROR,
          "Error serializing result for method: " + rpcRequest.getMethod());

    } catch (Exception ex) {
      LOGGER.error(
          "Unexpected error invoking method {}: {}", rpcRequest.getMethod(), ex.getMessage());
      handleErrorResponse(
          response,
          HttpResponseStatus.INTERNAL_SERVER_ERROR,
          "Unexpected error invoking method: " + rpcRequest.getMethod());
    }
  }

  private void invokePerlAppMethod(
      HttpResponse response, String rpcMethodName, String contentString) {
    LOGGER.warn("Method {} not found in rpcMethods. Trying perl-app.", rpcMethodName);
    String perlAppResponse = sendPostToPerlApp("http://perlapp:13360/jsonrpc", contentString);
    setJsonResponse(response, perlAppResponse);
  }

  private void handleHelloEndpoint(MessageEvent e) {
    HttpResponse response = new DefaultHttpResponse(HttpVersion.HTTP_1_1, HttpResponseStatus.OK);
    response.setHeader("Content-Type", "text/plain; charset=UTF-8");
    response.setHeader("Content-Length", response.getContent().readableBytes());

    String content = "Hello from Wrapper/Netty";
    LOGGER.info("Hello-Endpoint in Wrapper/Netty.");
    response.setContent(ChannelBuffers.copiedBuffer(content, StandardCharsets.UTF_8));

    sendResponse(e, response);
  }

  private void handle404Response(MessageEvent e) {
    HttpResponse response =
        new DefaultHttpResponse(HttpVersion.HTTP_1_1, HttpResponseStatus.NOT_FOUND);
    response.setHeader("Content-Type", "text/plain; charset=UTF-8");
    response.setHeader("Content-Length", response.getContent().readableBytes());

    String content = "404 Not Found";
    LOGGER.info("404-Endpoint in Wrapper/Netty.");
    response.setContent(ChannelBuffers.copiedBuffer(content, StandardCharsets.UTF_8));

    sendResponse(e, response);
  }

  private String extractRequestContent(HttpRequest request) {
    ChannelBuffer content = request.getContent();
    return content.toString(StandardCharsets.UTF_8);
  }

  private void setJsonResponse(HttpResponse response, String jsonResponse) {
    response.setContent(ChannelBuffers.copiedBuffer(jsonResponse, StandardCharsets.UTF_8));
    response.setHeader("Content-Type", "application/json");
  }

  private void handleErrorResponse(
      HttpResponse response, HttpResponseStatus status, String errorMessage) {
    response.setStatus(status);
    response.setContent(ChannelBuffers.copiedBuffer(errorMessage, StandardCharsets.UTF_8));
  }

  private void sendResponse(MessageEvent e, HttpResponse response) {
    ChannelFuture future = e.getChannel().write(response);
    future.addListener(ChannelFutureListener.CLOSE);
  }

  public String sendPostToPerlApp(String urlStr, String jsonPayload) {
    String responseBody = "";
    try {
      URL url = new URL(urlStr);
      HttpURLConnection connection = (HttpURLConnection) url.openConnection();

      connection.setRequestMethod("POST");
      connection.setRequestProperty("Content-Type", "application/json; utf-8");
      connection.setRequestProperty("Accept", "application/json");
      connection.setDoOutput(true);

      try (OutputStream os = connection.getOutputStream()) {
        byte[] input = jsonPayload.getBytes(StandardCharsets.UTF_8);
        os.write(input, 0, input.length);
      }

      int responseCode = connection.getResponseCode();
      LOGGER.info("Response Code: {}", responseCode);

      if (responseCode == HttpURLConnection.HTTP_OK) {
        try (BufferedReader br =
            new BufferedReader(
                new InputStreamReader(connection.getInputStream(), StandardCharsets.UTF_8))) {
          responseBody = br.lines().collect(Collectors.joining("\n"));
          LOGGER.info("Response from perl app: {}", responseBody);
        }
      } else {
        LOGGER.info("POST request failed. Response Code: {}", responseCode);
      }

    } catch (Exception e) {
      LOGGER.error("Error while sending POST request to Perl App", e);
    }
    return responseBody;
  }
}
