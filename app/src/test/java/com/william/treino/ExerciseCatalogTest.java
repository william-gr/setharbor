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
 @Test public void incompatibleCatalogVersionsAndDuplicateIdsAreRejected() throws Exception {
  JSONObject data=read("exercise-catalog.json");
  assertThrows(Exception.class,()->new ExerciseCatalog(new JSONObject(data.toString()).put("format","other")));
  assertThrows(Exception.class,()->new ExerciseCatalog(new JSONObject(data.toString()).put("schemaVersion",2)));
  for(String table:new String[]{"groups","exercises"}) {
   JSONObject duplicate=new JSONObject(data.toString());JSONArray rows=duplicate.getJSONArray(table);rows.put(new JSONObject(rows.getJSONObject(0).toString()));
   assertThrows(Exception.class,()->new ExerciseCatalog(duplicate));
  }
 }
 @Test public void missingReferencesAndAmbiguousAliasesAreRejected() throws Exception {
  for(String field:new String[]{"group","movementPattern","substitutionFamily","primaryMuscles","secondaryMuscles","stabilizerMuscles","equipment"}) {
   JSONObject data=read("exercise-catalog.json");JSONObject ex=data.getJSONArray("exercises").getJSONObject(0);
   ex.put(field,ex.get(field) instanceof JSONArray?new JSONArray().put("missing"):"missing");
   assertThrows(Exception.class,()->new ExerciseCatalog(data));
  }
  for(String field:new String[]{"primaryMuscles","equipment"}) {
   JSONObject data=read("exercise-catalog.json");data.getJSONArray("exercises").getJSONObject(0).put(field,new JSONArray());
   assertThrows(Exception.class,()->new ExerciseCatalog(data));
  }
  JSONObject data=read("exercise-catalog.json");JSONArray rows=data.getJSONArray("exercises");
  rows.getJSONObject(1).getJSONArray("aliases").put(rows.getJSONObject(0).getJSONObject("name").getString("pt"));
  assertThrows(Exception.class,()->new ExerciseCatalog(data));
 }
 @Test public void labelsAliasesAndLoadUnitsGiveUsableDetails() throws Exception {
  JSONObject ex=catalog.get("barbell-bench-press");
  assertEquals(ex,catalog.resolve(new JSONObject().put("name","  BARBELL BENCH PRESS  ")));
  assertEquals(catalog.label("muscles",ex.getJSONArray("primaryMuscles").getString(0)),catalog.labels("muscles",new JSONArray().put(ex.getJSONArray("primaryMuscles").getString(0))));
  assertEquals("",catalog.labels("muscles",new JSONArray()));
  assertThrows(IllegalStateException.class,()->catalog.labels("muscles",new JSONArray().put("missing")));
  String[] units={"per-dumbbell","per-side","bodyweight","assistance","band","total"};
  String[] hints={"Carga por halter","Carga por lado","0 kg sem carga adicional","Assistência em kg · reduza para progredir","Resistência de elástico","Carga total em kg"};
  for(int i=0;i<units.length;i++)assertEquals(hints[i],catalog.loadHint(new JSONObject().put("loadUnit",units[i])));
 }
 @Test public void similarityRequiresEveryMovementConstraintAndCompatibleRecording() throws Exception {
  JSONObject ex=catalog.get("barbell-bench-press");
  for(String field:new String[]{"group","substitutionFamily","movementPattern","mechanic"})assertFalse(catalog.similar(ex,new JSONObject(ex.toString()).put(field,"different")));
  assertTrue(catalog.alternatives(null).isEmpty());
  for(JSONObject current:catalog.all())for(JSONObject option:catalog.alternatives(current)) {
   assertNotEquals("band",option.getString("loadUnit"));assertNotEquals("isometric",option.getString("mechanic"));
  }
 }
 @Test public void customAndFutureExercisesKeepIdentityAndCannotBeSwapped() throws Exception {
  JSONObject custom=new JSONObject(first().toString()).put("id","custom").put("name","Custom");custom.remove("catalogId");
  assertEquals(custom.toString(),ExerciseSession.effective(custom,new JSONObject(),catalog).toString());
  JSONObject unknown=new JSONObject(custom.toString()).put("catalogId","future-a");
  assertTrue(ExerciseSession.sameExercise(unknown,new JSONObject(unknown.toString()).put("id","another-slot"),catalog));
  assertFalse(ExerciseSession.sameExercise(unknown,new JSONObject(unknown.toString()).put("catalogId","future-b"),catalog));
  assertFalse(ExerciseSession.sameExercise(custom,new JSONObject(custom.toString()).put("id","different"),catalog));
  JSONObject customPlan=new JSONObject(plan.toString());customPlan.getJSONArray("days").getJSONObject(0).getJSONArray("exercises").put(0,custom);
  JSONObject draft=new JSONObject();assertThrows(Exception.class,()->ExerciseSession.switchTo(customPlan,0,0,draft,catalog,"dumbbell-bench-press"));assertEquals(0,draft.length());
 }
 @Test public void malformedOverrideTypesAndUnknownExercisesFailWithoutMutation() throws Exception {
  JSONObject unknown=new JSONObject().put(ExerciseSession.OVERRIDES,new JSONObject().put("legacy-0-0","missing"));
  assertThrows(JSONException.class,()->ExerciseSession.effective(first(),unknown,catalog));
  for(Object value:new Object[]{"wrong type",JSONObject.NULL,new JSONObject().put("legacy-0-0",17)}) {
   JSONObject draft=new JSONObject().put(ExerciseSession.OVERRIDES,value);String before=draft.toString();
   assertThrows(Exception.class,()->ExerciseSession.validateOverrides(plan,0,draft,catalog));assertEquals(before,draft.toString());
  }
  ExerciseSession.validateOverrides(plan,0,new JSONObject(),catalog);
  ExerciseSession.validateOverrides(plan,0,new JSONObject().put(ExerciseSession.OVERRIDES,new JSONObject()),catalog);
 }
 @Test public void returningOneSwapPreservesOtherOverridesAndSnapshotDays() throws Exception {
  JSONObject draft=new JSONObject().put(ExerciseSession.OVERRIDES,new JSONObject().put("legacy-0-1","incline-dumbbell-bench-press"));
  ExerciseSession.switchTo(plan,0,0,draft,catalog,"dumbbell-bench-press");
  ExerciseSession.switchTo(plan,0,0,draft,catalog,"barbell-bench-press");
  assertEquals("incline-dumbbell-bench-press",draft.getJSONObject(ExerciseSession.OVERRIDES).getString("legacy-0-1"));
  assertFalse(draft.getJSONObject(ExerciseSession.OVERRIDES).has("legacy-0-0"));
  JSONObject saved=ExerciseSession.snapshot(plan,0,draft,catalog);
  assertEquals(plan.getJSONArray("days").getJSONObject(1).toString(),saved.getJSONArray("days").getJSONObject(1).toString());
 }
}
