package com.sippy.wrapper.parent;

import javax.ejb.EJB;
import javax.ejb.Stateless;
import javax.ws.rs.*;
import javax.ws.rs.core.MediaType;
import javax.ws.rs.core.Response;
import org.sippi.WrapperStartup;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

@Stateless
@Path("/")
public class Maintenance {

  private static final Logger LOGGER = LoggerFactory.getLogger(Maintenance.class);

  @EJB private WrapperStartup wrapperServer;

  @POST
  @Path("/wrapper/shutdown")
  @Consumes({MediaType.APPLICATION_FORM_URLENCODED})
  @Produces({MediaType.APPLICATION_JSON})
  public Response wrapperShutwown() throws Exception {
    Response response;

    LOGGER.info("wrapper shutdown was called");
    wrapperServer.applicationShutdown();
    response = Response.ok().build();
    LOGGER.info("wrapper shutdown success ");

    return response;
  }

  @GET
  @Path("/health")
  public Response healthCheck() {
    Response response;

    response = Response.ok("Health check in War is happy :)").status(200).build();

    return response;
  }
}
