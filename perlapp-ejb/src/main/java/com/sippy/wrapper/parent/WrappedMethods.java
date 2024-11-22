package com.sippy.wrapper.parent;

import com.sippy.wrapper.parent.database.DatabaseConnection;
import com.sippy.wrapper.parent.request.JavaTestRequest;
import com.sippy.wrapper.parent.request.TnbListRequest;
import com.sippy.wrapper.parent.response.JavaTestResponse;
import java.util.*;
import javax.ejb.EJB;
import javax.ejb.Stateless;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

@Stateless
public class WrappedMethods {

  private static final Logger LOGGER = LoggerFactory.getLogger(WrappedMethods.class);

  @EJB DatabaseConnection databaseConnection;

  @RpcMethod(name = "javaTest", description = "Check if everything works :)")
  public Map<String, Object> javaTest(JavaTestRequest request) {
    JavaTestResponse response = new JavaTestResponse();

    int count = databaseConnection.getAllTnbs().size();

    LOGGER.info("the count is: " + count);

    response.setId(request.getId());
    String tempFeeling = request.isTemperatureOver20Degree() ? "warm" : "cold";
    response.setOutput(
        String.format(
            "%s has a rather %s day. And he has %d tnbs", request.getName(), tempFeeling, count));

    Map<String, Object> jsonResponse = new HashMap<>();
    jsonResponse.put("faultCode", "200");
    jsonResponse.put("faultString", "Method success");
    jsonResponse.put("something", response);

    return jsonResponse;
  }

  public record TnbEntry(String tnb, String name, boolean isTnb) {}

  @RpcMethod(name = "getTnbList", description = "Actual Request")
  public Map<String, Object> getTnbList(final TnbListRequest request) {
    LOGGER.info("Fetching TNB list from the database");
    final var tnbs_from_list = databaseConnection.getAllTnbs();

    Optional<String> validatedTnb;
    final String number = request.number();
    if (number == null) {
      validatedTnb = Optional.empty();
    } else {
      validatedTnb = databaseConnection.getTnbByTnb(number);
    }

    final List<TnbEntry> tnbs = new ArrayList<>();
    tnbs.add(new TnbEntry("D001", "Deutsche Telekom", isTnb(validatedTnb, "D001")));

    tnbs_from_list.stream()
            .filter(tnbDao -> !tnbDao.getTnb().matches("(D146|D218|D248)"))
            .map(tnbDao -> new TnbEntry(tnbDao.getTnb(), tnbDao.getName(), isTnb(validatedTnb, tnbDao.getName())))
            .forEach(tnbs::add);

    tnbs.sort((a, b) -> a.name().compareToIgnoreCase(b.name()));

    Map<String, Object> jsonResponse = new HashMap<>();
    jsonResponse.put("faultCode", "200");
    jsonResponse.put("faultString", "Method success");
    jsonResponse.put("tnbs", tnbs);

    return jsonResponse;
  }

  private boolean isTnb(final Optional<String> providedTnb, final String comparedTnb) {
    return providedTnb.map(s -> s.equals(comparedTnb)).orElse(false);
  }
}
