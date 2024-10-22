package org.sippi;

import com.sippy.wrapper.parent.RpcMethod;
import com.sippy.wrapper.parent.WrappedMethods;
import java.lang.reflect.Method;
import java.util.HashMap;
import java.util.Map;
import javax.ejb.Singleton;

@Singleton
public class RpcMethodHolder {

  private Class<RpcMethod> rpcAnnotation = RpcMethod.class;
  private final Map<String, Method> rpcMethods;

  public RpcMethodHolder() {
    Class<WrappedMethods> targetClass = WrappedMethods.class;
    rpcMethods = fetchRpcMethods(targetClass.getMethods());
  }

  public Map<String, Method> getRpcMethods() {
    return rpcMethods;
  }

  private Map<String, Method> fetchRpcMethods(Method[] targetMethods) {
    Map<String, Method> back = new HashMap();
    Method[] var2 = targetMethods;
    int var3 = targetMethods.length;

    for (int var4 = 0; var4 < var3; ++var4) {
      Method currentMethod = var2[var4];
      String methodName = fetchRpcMethodName(currentMethod);
      if (methodName != null) {
        back.put(methodName, currentMethod);
      }
    }

    return back;
  }

  private String fetchRpcMethodName(Method targetMethod) {
    String back = null;
    if (targetMethod.isAnnotationPresent(rpcAnnotation)) {
      RpcMethod annotation = targetMethod.getAnnotation(rpcAnnotation);
      back = annotation.name();
    }

    return back;
  }
}
