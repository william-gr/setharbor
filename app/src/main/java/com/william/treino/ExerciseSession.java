package com.william.treino;

import org.json.*;
import java.util.*;

/** Session overrides live inside the existing per-day draft and backup. */
public final class ExerciseSession {
 public static final String OVERRIDES="exerciseOverrides";
 public static JSONObject planned(JSONObject plan,int day,int exercise) throws JSONException {return plan.getJSONArray("days").getJSONObject(day).getJSONArray("exercises").getJSONObject(exercise);}
 public static JSONObject effective(JSONObject planned,JSONObject draft,ExerciseCatalog catalog) throws JSONException {
  JSONObject item=new JSONObject(planned.toString());JSONObject overrides=draft.optJSONObject(OVERRIDES);
  if(overrides==null||!overrides.has(planned.getString("id"))) {
   JSONObject known=catalog.resolve(planned);if(known!=null)item.put("catalogId",known.getString("id"));return item;
  }
  JSONObject actual=catalog.get(overrides.getString(planned.getString("id")));
  if(actual==null)throw new JSONException("Exercício desconhecido");
  item.put("catalogId",actual.getString("id"));item.put("name",catalog.name(actual));return item;
 }
 public static boolean hasData(JSONObject draft,int exercise,int sets) {
  for(int s=0;s<sets;s++){String k=exercise+"_"+s;if(!draft.optString(k+"kg").trim().isEmpty()||!draft.optString(k+"reps").trim().isEmpty()||draft.optBoolean(k+"done"))return true;}
  return false;
 }
 public static void switchTo(JSONObject plan,int day,int exercise,JSONObject draft,ExerciseCatalog catalog,String target) throws Exception {
  JSONObject planned=planned(plan,day,exercise);
  if(hasData(draft,exercise,planned.getInt("sets")))throw new Exception("Apague os dados deste exercício antes de trocar.");
  JSONObject current=catalog.resolve(effective(planned,draft,catalog)),next=catalog.get(target);
  if(current==null||next==null||!catalog.alternatives(current).contains(next))throw new Exception("Sem alternativa compatível");
  JSONObject overrides=draft.optJSONObject(OVERRIDES);if(overrides==null)overrides=new JSONObject();
  JSONObject original=catalog.resolve(planned);
  if(original!=null&&original.getString("id").equals(target))overrides.remove(planned.getString("id"));else overrides.put(planned.getString("id"),target);
  if(overrides.length()==0)draft.remove(OVERRIDES);else draft.put(OVERRIDES,overrides);
 }
 public static JSONObject snapshot(JSONObject plan,int day,JSONObject draft,ExerciseCatalog catalog) throws JSONException {
  JSONObject result=new JSONObject(plan.toString());JSONArray items=result.getJSONArray("days").getJSONObject(day).getJSONArray("exercises");
  for(int e=0;e<items.length();e++)items.put(e,effective(items.getJSONObject(e),draft,catalog));return result;
 }
 public static boolean sameExercise(JSONObject a,JSONObject b,ExerciseCatalog catalog) {
  JSONObject ca=catalog.resolve(a),cb=catalog.resolve(b);
  if(ca!=null&&cb!=null)return ca.optString("id").equals(cb.optString("id"));
  if(a.has("catalogId")||b.has("catalogId"))return a.optString("catalogId").equals(b.optString("catalogId"));
  return a.optString("id").equals(b.optString("id"));
 }
 public static void validateOverrides(JSONObject plan,int day,JSONObject draft,ExerciseCatalog catalog) throws Exception {
  if(!draft.has(OVERRIDES))return;JSONObject overrides=draft.getJSONObject(OVERRIDES);
  JSONArray items=plan.getJSONArray("days").getJSONObject(day).getJSONArray("exercises");Set<String> seen=new HashSet<>();
  for(int e=0;e<items.length();e++) {
   JSONObject item=items.getJSONObject(e);String slot=item.getString("id");seen.add(slot);
   if(!overrides.has(slot))continue;
   JSONObject original=catalog.resolve(item),actual=catalog.get(overrides.getString(slot));
   if(original==null||actual==null||!catalog.similar(original,actual))throw new Exception("Troca incompatível no backup");
  }
  Iterator<String> keys=overrides.keys();while(keys.hasNext())if(!seen.contains(keys.next()))throw new Exception("Posição desconhecida no backup");
 }
}
