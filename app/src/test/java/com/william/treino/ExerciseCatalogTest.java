package com.william.treino;

import org.json.*;
import org.junit.*;
import static org.junit.Assert.*;
import java.nio.file.*;
import java.util.*;

public class ExerciseCatalogTest {
 ExerciseCatalog catalog;JSONObject plan;
 @Before public void load() throws Exception {
  catalog=new ExerciseCatalog(read("exercise-catalog.json"));plan=read("default-plan.json");catalog.bindLegacyPlan(plan);
 }
 JSONObject read(String name) throws Exception {return new JSONObject(new String(Files.readAllBytes(Paths.get("src/main/assets/"+name)),java.nio.charset.StandardCharsets.UTF_8));}
 JSONObject first() throws Exception {return ExerciseSession.planned(plan,0,0);}
 @Test public void bundledReferencesAndPlanResolve() throws Exception {
  assertEquals(90,catalog.all().size());WorkoutPlan.validate(plan);
  for(int d=0;d<plan.getJSONArray("days").length();d++) {
   JSONArray items=plan.getJSONArray("days").getJSONObject(d).getJSONArray("exercises");
   for(int e=0;e<items.length();e++)assertNotNull(catalog.resolve(items.getJSONObject(e)));
  }
 }
 @Test public void equivalentLegacyNamesResolveWithoutCatalogIds() throws Exception {
  JSONObject legacy=new JSONObject(first().toString());legacy.remove("catalogId");
  assertTrue(ExerciseSession.sameExercise(first(),legacy,catalog));
  assertEquals("barbell-bench-press",catalog.resolve(new JSONObject().put("name","SUPINO RETO BARRA")).getString("id"));
 }
 @Test public void movementFamiliesExcludeOtherRoles() {
  Set<String> ids=new HashSet<>();for(JSONObject ex:catalog.alternatives(catalog.get("barbell-romanian-deadlift")))ids.add(ex.optString("id"));
  assertTrue(ids.contains("dumbbell-romanian-deadlift"));assertFalse(ids.contains("seated-leg-curl"));assertFalse(ids.contains("barbell-romanian-deadlift"));
  for(JSONObject ex:catalog.alternatives(catalog.get("standing-machine-calf-raise")))assertFalse(ex.optString("id").equals("seated-machine-calf-raise"));
 }
 @Test public void noAlternativeIsReportedWithoutChangingMovementFamily() throws Exception {
  assertTrue(catalog.alternatives(catalog.get("machine-leg-extension")).isEmpty());
  for(JSONObject day:iter(plan.getJSONArray("days")))for(JSONObject ex:iter(day.getJSONArray("exercises"))) {
   JSONObject known=catalog.resolve(ex);if(!known.optString("id").equals("machine-leg-extension"))assertFalse(catalog.alternatives(known).isEmpty());
  }
 }
 List<JSONObject> iter(JSONArray array) throws Exception {List<JSONObject> items=new ArrayList<>();for(int i=0;i<array.length();i++)items.add(array.getJSONObject(i));return items;}
 @Test public void switchingKeepsPlanSlotPrescriptionAndOtherDraftData() throws Exception {
  String original=plan.toString();JSONObject draft=new JSONObject().put("1_0kg","20");
  ExerciseSession.switchTo(plan,0,0,draft,catalog,"dumbbell-bench-press");
  JSONObject actual=ExerciseSession.effective(first(),draft,catalog);
  assertEquals("legacy-0-0",actual.getString("id"));assertEquals(3,actual.getInt("sets"));assertEquals("6–8",actual.getString("reps"));
  assertEquals("Supino reto halteres",actual.getString("name"));assertEquals("20",draft.getString("1_0kg"));assertEquals(original,plan.toString());
 }
 @Test public void anyEnteredFieldOrHiddenSetBlocksSwitch() throws Exception {
  for(String key:new String[]{"0_0kg","0_0reps","0_2kg","0_2done"}) {
   JSONObject draft=new JSONObject().put(key,key.endsWith("done")?true:"0");String before=draft.toString();
   assertThrows(Exception.class,()->ExerciseSession.switchTo(plan,0,0,draft,catalog,"dumbbell-bench-press"));assertEquals(before,draft.toString());
  }
 }
 @Test public void clearedFieldsAllowSwitchAndReturningRemovesOverride() throws Exception {
  JSONObject draft=new JSONObject().put("0_0kg","").put("0_0done",false);
  ExerciseSession.switchTo(plan,0,0,draft,catalog,"dumbbell-bench-press");
  ExerciseSession.switchTo(plan,0,0,draft,catalog,"barbell-bench-press");assertFalse(draft.has(ExerciseSession.OVERRIDES));
 }
 @Test public void sameCurrentAndUnrelatedTargetAreRejected() throws Exception {
  JSONObject draft=new JSONObject();
  assertThrows(Exception.class,()->ExerciseSession.switchTo(plan,0,0,draft,catalog,"barbell-bench-press"));
  assertThrows(Exception.class,()->ExerciseSession.switchTo(plan,0,0,draft,catalog,"seated-leg-curl"));assertEquals(0,draft.length());
 }
 @Test public void draftRoundTripAndSnapshotRetainSwapButNextSessionResets() throws Exception {
  JSONObject draft=new JSONObject();ExerciseSession.switchTo(plan,0,0,draft,catalog,"dumbbell-bench-press");draft.put("0_0kg","15");
  JSONObject restored=new JSONObject(draft.toString());ExerciseSession.validateOverrides(plan,0,restored,catalog);
  JSONObject saved=ExerciseSession.snapshot(plan,0,restored,catalog);
  assertEquals("dumbbell-bench-press",ExerciseSession.planned(saved,0,0).getString("catalogId"));assertFalse(ExerciseSession.sameExercise(first(),ExerciseSession.planned(saved,0,0),catalog));
  assertEquals("barbell-bench-press",ExerciseSession.effective(first(),new JSONObject(),catalog).getString("catalogId"));
  restored.getJSONObject(ExerciseSession.OVERRIDES).put("legacy-0-0","smith-bench-press");assertEquals("dumbbell-bench-press",ExerciseSession.planned(saved,0,0).getString("catalogId"));
 }
 @Test public void matchingCatalogAcrossPlanPositionsKeepsLoadsSeparate() throws Exception {
  JSONObject a=first(),same=new JSONObject(a.toString()).put("id","new-slot"),different=new JSONObject(a.toString()).put("catalogId","dumbbell-bench-press");
  assertTrue(ExerciseSession.sameExercise(a,same,catalog));assertFalse(ExerciseSession.sameExercise(a,different,catalog));
  JSONObject custom=new JSONObject().put("id","custom").put("name","Custom exercise");assertTrue(ExerciseSession.sameExercise(custom,new JSONObject(custom.toString()),catalog));
 }
 @Test public void malformedBackupOverridesRejectBeforeMutation() throws Exception {
  for(String target:new String[]{"missing","seated-leg-curl"}) {
   JSONObject draft=new JSONObject().put(ExerciseSession.OVERRIDES,new JSONObject().put("legacy-0-0",target));
   assertThrows(Exception.class,()->ExerciseSession.validateOverrides(plan,0,draft,catalog));
  }
  JSONObject unknownSlot=new JSONObject().put(ExerciseSession.OVERRIDES,new JSONObject().put("missing-slot","dumbbell-bench-press"));
  assertThrows(Exception.class,()->ExerciseSession.validateOverrides(plan,0,unknownSlot,catalog));
 }
 @Test public void explicitUnknownCatalogIdDoesNotFallBackToName() throws Exception {
  assertNull(catalog.resolve(new JSONObject(first().toString()).put("catalogId","future-exercise")));
 }
 @Test public void renamedLegacyPlanKeepsHistoryIdentityWithoutNewField() throws Exception {
  JSONObject imported=new JSONObject(first().toString());imported.remove("catalogId");imported.put("name","Supino atualizado");
  assertTrue(ExerciseSession.sameExercise(imported,first(),catalog));
  assertEquals("barbell-bench-press",ExerciseSession.effective(imported,new JSONObject(),catalog).getString("catalogId"));
 }
}
