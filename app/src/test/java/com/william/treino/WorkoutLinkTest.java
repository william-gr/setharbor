package com.william.treino;

import java.nio.charset.StandardCharsets;
import java.nio.file.*;
import java.util.Base64;
import org.json.*;
import org.junit.Test;
import static org.junit.Assert.*;

public class WorkoutLinkTest {
 JSONObject plan() throws Exception {return new JSONObject(new String(Files.readAllBytes(Paths.get("src/main/assets/default-plan.json")), StandardCharsets.UTF_8));}
 String payload(String json){return Base64.getUrlEncoder().withoutPadding().encodeToString(json.getBytes(StandardCharsets.UTF_8));}
 @Test public void webAndAppLinksRoundTripRealPlanAndUnicode() throws Exception {
  JSONObject p=plan().put("title","Força 💪 · café + & #");String web=WorkoutLink.encode(p);
  assertEquals(p.toString(),WorkoutLink.parse(web).toString());
  assertEquals(p.toString(),WorkoutLink.parse(web.replace(WorkoutLink.WEB_BASE,WorkoutLink.APP_BASE)).toString());
 }
 @Test public void realisticThreeDayPlanFitsAndRoundTrips() throws Exception {
  JSONObject p=plan();JSONArray days=p.getJSONArray("days");days.remove(4);days.remove(3);
  assertEquals(3,WorkoutLink.parse(WorkoutLink.encode(p)).getJSONArray("days").length());
 }
 @Test public void onlyExactDestinationsAndVersionAreAccepted() throws Exception {
  String fragment="#v1."+payload(plan().toString());
  for(String base:new String[]{"http://william-gr.github.io/setharbor/open/","https://evil.example/setharbor/open/","https://william-gr.github.io/setharbor/other/","https://william-gr.github.io:443/setharbor/open/","https://user@william-gr.github.io/setharbor/open/",WorkoutLink.WEB_BASE+"?plan=1","setharbor://other","setharbor://workout/path","file:///setharbor/open/"})
   assertThrows(Exception.class,()->WorkoutLink.parse(base+fragment));
  for(String fragmentPart:new String[]{"","#v2.YQ","#v1.","#v1.YQ=","#v1.%20","#v1.A"})
   assertThrows(Exception.class,()->WorkoutLink.parse(WorkoutLink.WEB_BASE+fragmentPart));
 }
 @Test public void invalidJsonInvalidUtf8AndInvalidPlanAreRejected() throws Exception {
  for(String content:new String[]{"not json","{}",plan().put("revision",0).toString()})
   assertThrows(Exception.class,()->WorkoutLink.parse(WorkoutLink.WEB_BASE+"#v1."+payload(content)));
  assertThrows(Exception.class,()->WorkoutLink.parse(WorkoutLink.WEB_BASE+"#v1._w"));
 }
 @Test public void sizeLimitsApplyToIncomingAndGeneratedLinks() throws Exception {
  assertThrows(Exception.class,()->WorkoutLink.parse(null));
  assertThrows(Exception.class,()->WorkoutLink.parse("x".repeat(WorkoutLink.MAX_LENGTH+1)));
  assertThrows(Exception.class,()->WorkoutLink.encode(plan().put("padding","x".repeat(64000))));
 }
}
