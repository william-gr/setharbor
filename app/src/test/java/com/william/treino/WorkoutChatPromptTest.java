package com.william.treino;

import java.nio.file.*;
import org.json.*;
import org.junit.Test;
import static org.junit.Assert.*;

public class WorkoutChatPromptTest {
 JSONObject asset(String name) throws Exception {return new JSONObject(new String(Files.readAllBytes(Paths.get("src/main/assets/"+name)), java.nio.charset.StandardCharsets.UTF_8));}
 @Test public void newPlanPromptStaysShortWithoutCatalogOrCurrentPlan() throws Exception {
  JSONObject plan=asset("default-plan.json");String prompt=WorkoutChatPrompt.create(plan,false);
  assertTrue(prompt.length()<650);assertTrue(prompt.contains(WorkoutChatPrompt.GUIDE_URL));
  assertTrue(prompt.contains("antes de criar"));assertTrue(prompt.contains("não invente"));
  assertTrue(prompt.contains("Revisão atual: 1"));assertFalse(prompt.contains("Ficha atual:"));
  assertFalse(prompt.contains("barbell-bench-press"));assertFalse(prompt.contains(plan.getString("title")));
  plan.put("padding","PRIVATE_MARKER".repeat(1000));assertEquals(prompt,WorkoutChatPrompt.create(plan,false));
 }
 @Test public void reviewIncludesOnlyCurrentPlanAndGuideLink() throws Exception {
  JSONObject plan=asset("default-plan.json");String prompt=WorkoutChatPrompt.create(plan,true);
  assertTrue(prompt.contains(plan.toString()));assertTrue(prompt.contains(WorkoutChatPrompt.GUIDE_URL));
  assertTrue(prompt.contains("revisar minha ficha"));assertFalse(prompt.contains("Catálogo:"));
  assertFalse(prompt.contains("lastPerformance"));assertFalse(prompt.contains("draft0"));
 }
 @Test public void invalidPlanCannotBeSharedInEitherMode() throws Exception {
  for(boolean review:new boolean[]{false,true})assertThrows(Exception.class,()->WorkoutChatPrompt.create(new JSONObject(),review));
 }
 @Test public void extraImportedMetadataIsExcludedAndOptionalFieldsMayBeAbsent() throws Exception {
  JSONObject plan=asset("default-plan.json");plan.put("history","PRIVATE_SESSION_MARKER");
  JSONObject day=plan.getJSONArray("days").getJSONObject(0);day.remove("focus");day.put("draft0","PRIVATE_DRAFT_MARKER");
  JSONObject item=day.getJSONArray("exercises").getJSONObject(0);item.remove("catalogId");item.put("kg","PRIVATE_LOAD_MARKER");
  String prompt=WorkoutChatPrompt.create(plan,true);
  assertFalse(prompt.contains("PRIVATE_"));assertTrue(prompt.contains(item.getString("name")));
 }
}
