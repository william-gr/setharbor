package com.william.treino;

import org.json.*;
import org.junit.Test;
import static org.junit.Assert.*;

public class WorkoutPlanTest {
 JSONObject exercise(String id) throws Exception {return new JSONObject().put("id",id).put("name","Custom").put("sets",1).put("reps","8–12");}
 JSONObject day(String id,int count) throws Exception {
  JSONArray items=new JSONArray();for(int i=0;i<count;i++)items.put(exercise(id+"-"+i));
  return new JSONObject().put("id",id).put("name","Day").put("exercises",items);
 }
 JSONObject plan(int days,int exercises) throws Exception {
  JSONArray items=new JSONArray();for(int i=0;i<days;i++)items.put(day("day-"+i,exercises));
  return new JSONObject().put("format","meu-treino-plan").put("schemaVersion",1).put("revision",1).put("title","Plan").put("days",items);
 }
 JSONObject first(JSONObject plan) throws Exception {return plan.getJSONArray("days").getJSONObject(0).getJSONArray("exercises").getJSONObject(0);}
 @Test public void supportedLimitsAndOptionalFutureCatalogIdsAreAccepted() throws Exception {
  WorkoutPlan.validate(plan(1,1));JSONObject p=plan(7,20);
  p.put("title","x".repeat(120));first(p).put("catalogId","future-id").put("sets",10);
  p.getJSONArray("days").getJSONObject(0).put("focus","x".repeat(200));WorkoutPlan.validate(p);
 }
 @Test public void incompatibleHeaderAndNonpositiveRevisionAreRejected() throws Exception {
  assertThrows(Exception.class,()->WorkoutPlan.validate(plan(1,1).put("format","other")));
  assertThrows(Exception.class,()->WorkoutPlan.validate(plan(1,1).put("schemaVersion",2)));
  for(int revision:new int[]{0,-1})assertThrows(Exception.class,()->WorkoutPlan.validate(plan(1,1).put("revision",revision)));
 }
 @Test public void dayExerciseAndSetLimitsAreEnforced() throws Exception {
  for(int count:new int[]{0,8})assertThrows(Exception.class,()->WorkoutPlan.validate(plan(count,1)));
  for(int count:new int[]{0,21})assertThrows(Exception.class,()->WorkoutPlan.validate(plan(1,count)));
  for(int sets:new int[]{0,11}) {JSONObject p=plan(1,1);first(p).put("sets",sets);assertThrows(Exception.class,()->WorkoutPlan.validate(p));}
 }
 @Test public void duplicateDaysAndExerciseIdsAcrossDaysAreRejected() throws Exception {
  JSONObject p=plan(2,1);p.getJSONArray("days").getJSONObject(1).put("id","day-0");assertThrows(Exception.class,()->WorkoutPlan.validate(p));
  JSONObject q=plan(2,1);first(q).put("id","day-1-0");assertThrows(Exception.class,()->WorkoutPlan.validate(q));
 }
 @Test public void blankAndOverlongTextsAndMalformedCatalogIdsAreRejected() throws Exception {
  for(String text:new String[]{"  ","x".repeat(121)})assertThrows(Exception.class,()->WorkoutPlan.validate(plan(1,1).put("title",text)));
  for(Object id:new Object[]{" ","x".repeat(81),JSONObject.NULL,17}) {
   JSONObject p=plan(1,1);first(p).put("catalogId",id);assertThrows(Exception.class,()->WorkoutPlan.validate(p));
  }
  JSONObject p=plan(1,1);p.getJSONArray("days").getJSONObject(0).put("focus","");assertThrows(Exception.class,()->WorkoutPlan.validate(p));
 }
 @Test public void missingRequiredFieldsAndWrongContainerTypesAreRejected() throws Exception {
  for(String field:new String[]{"format","schemaVersion","revision","title","days"}) {
   JSONObject p=plan(1,1);p.remove(field);assertThrows(Exception.class,()->WorkoutPlan.validate(p));
  }
  JSONObject p=plan(1,1).put("days","wrong type");assertThrows(Exception.class,()->WorkoutPlan.validate(p));
  JSONObject q=plan(1,1);first(q).remove("sets");assertThrows(Exception.class,()->WorkoutPlan.validate(q));
 }
}
