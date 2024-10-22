package com.sippy.wrapper.parent;

import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;

@Retention(RetentionPolicy.RUNTIME)
public @interface RpcMethod {
  String name();

  String description() default "";
}
