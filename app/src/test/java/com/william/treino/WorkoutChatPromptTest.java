package com.william.treino;

import java.nio.file.*;
import org.json.*;
import org.junit.Test;
import static org.junit.Assert.*;

public class WorkoutChatPromptTest {
 JSONObject asset(String name) throws Exception {return new JSONObject(new String(Files.readAllBytes(Paths.get("src/main/assets/"+name)), java.nio.charset.StandardCharsets.UTF_8));}
 @Test public void sendsRealCatalogAndCurrentPlanWithExactEncodingInstructions() throws Exception {
  JSONObject plan=asset("default-plan.json"),catalog=asset("exercise-catalog.json");
  String prompt=WorkoutChatPrompt.create(plan,catalog);
  assertTrue(prompt.contains(plan.toString()));assertTrue(prompt.contains(WorkoutLink.WEB_BASE+"#v1."));
  assertTrue(prompt.contains("urlsafe_b64encode"));assertTrue(prompt.contains("ensure_ascii=False"));
  assertTrue(prompt.contains("antes de criar"));assertTrue(prompt.contains("não invente"));
  JSONArray items=catalog.getJSONArray("exercises");for(int i=0;i<items.length();i++)assertTrue(prompt.contains(items.getJSONObject(i).getString("id")));
  assertFalse(prompt.contains("lastPerformance"));assertFalse(prompt.contains("draft0"));
 }
 @Test public void invalidInputsCannotBeSharedAsAWorkingPrompt() throws Exception {
  assertThrows(Exception.class,()->WorkoutChatPrompt.create(new JSONObject(),asset("exercise-catalog.json")));
  assertThrows(Exception.class,()->WorkoutChatPrompt.create(asset("default-plan.json"),new JSONObject()));
 }
 @Test public void extraImportedMetadataIsExcludedAndOptionalFieldsMayBeAbsent() throws Exception {
  JSONObject plan=asset("default-plan.json");plan.put("history","PRIVATE_SESSION_MARKER");
  JSONObject day=plan.getJSONArray("days").getJSONObject(0);day.remove("focus");day.put("draft0","PRIVATE_DRAFT_MARKER");
  JSONObject item=day.getJSONArray("exercises").getJSONObject(0);item.remove("catalogId");item.put("kg","PRIVATE_LOAD_MARKER");
  String prompt=WorkoutChatPrompt.create(plan,asset("exercise-catalog.json"));
  assertFalse(prompt.contains("PRIVATE_"));assertTrue(prompt.contains(item.getString("name")));
 }
}
