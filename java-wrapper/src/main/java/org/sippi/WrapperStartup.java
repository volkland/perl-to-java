package org.sippi;

import java.net.InetSocketAddress;
import java.util.concurrent.Executors;
import javax.annotation.PostConstruct;
import javax.annotation.PreDestroy;
import javax.ejb.EJB;
import javax.ejb.Singleton;
import javax.ejb.Startup;
import org.jboss.netty.bootstrap.ServerBootstrap;
import org.jboss.netty.channel.Channel;
import org.jboss.netty.channel.ChannelPipeline;
import org.jboss.netty.channel.ChannelPipelineFactory;
import org.jboss.netty.channel.Channels;
import org.jboss.netty.channel.socket.nio.NioServerSocketChannelFactory;
import org.jboss.netty.handler.codec.http.HttpRequestDecoder;
import org.jboss.netty.handler.codec.http.HttpResponseEncoder;
import org.jboss.netty.handler.stream.ChunkedWriteHandler;

@Singleton
@Startup
public class WrapperStartup {

  @EJB private CustomServerHandler customServerHandler;

  private ServerBootstrap bootstrap;
  private Channel serverChannel;

  @PostConstruct
  public void applicationStartup() {
    try {
      // Configure the server
      bootstrap =
          new ServerBootstrap(
              new NioServerSocketChannelFactory(
                  Executors.newCachedThreadPool(), Executors.newCachedThreadPool()));

      // Set up the pipeline factory
      bootstrap.setPipelineFactory(
          new ChannelPipelineFactory() {
            public ChannelPipeline getPipeline() throws Exception {
              return Channels.pipeline(
                  new HttpRequestDecoder(),
                  new HttpResponseEncoder(),
                  new ChunkedWriteHandler(),
                  customServerHandler);
            }
          });

      // Bind and start to accept incoming connections
      serverChannel = bootstrap.bind(new InetSocketAddress(8099));
      System.out.println("Netty Server started on port 8099.");
    } catch (Exception e) {
      e.printStackTrace();
    }
  }

  @PreDestroy
  public void applicationShutdown() {
    try {
      if (serverChannel != null) {
        serverChannel.close().awaitUninterruptibly();
        System.out.println("Netty Server stopped.");
      }
      if (bootstrap != null) {
        bootstrap.releaseExternalResources();
      }
    } catch (Exception e) {
      e.printStackTrace();
    }
  }
}
