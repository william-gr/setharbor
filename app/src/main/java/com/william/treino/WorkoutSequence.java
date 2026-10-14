package com.william.treino;

import org.json.*;
import java.util.*;

/** Calendar-independent cursor; callers supply validated, nonempty plans. */
public final class WorkoutSequence {
 private WorkoutSequence() {}
 // Keep opaque identifiers escaped like the other JSON preference values.
 public static String encodeId(String id) {return new JSONArray().put(id).toString();}
 public static String decodeId(String stored) {
  try{JSONArray values=new JSONArray(stored);if(values.length()!=1)return "";Object id=values.get(0);return id instanceof String?(String)id:"";}catch(JSONException invalid){return "";}
 }
 public static String label(int index) { return "Treino "+(char)('A'+index); }
 public static String id(JSONObject plan,int index) throws JSONException { return plan.getJSONArray("days").getJSONObject(index).getString("id"); }
 public static int index(JSONObject plan,String id) throws JSONException {
  JSONArray days=plan.getJSONArray("days");
  for(int i=0;i<days.length();i++)if(id(plan,i).equals(id))return i;
  return -1;
 }
 public static String afterSave(JSONObject plan,String next,int completed) throws JSONException {
  int expected=index(plan,next);
  if(expected<0)throw new JSONException("Próximo treino inválido");
  return completed==expected?id(plan,(completed+1)%plan.getJSONArray("days").length()):next;
 }
 public static String revised(JSONObject plan,String next) throws JSONException { return index(plan,next)>=0?next:id(plan,0); }
 private static Set<String> ids(JSONObject plan) throws JSONException {
  Set<String> ids=new HashSet<>();for(int i=0;i<plan.getJSONArray("days").length();i++)ids.add(id(plan,i));return ids;
 }
 public static boolean related(JSONObject old,JSONObject revised) throws JSONException {Set<String> common=ids(old);common.retainAll(ids(revised));return !common.isEmpty();}
 public static String migrate(JSONObject plan,JSONArray history,int selection) throws JSONException {
  for(int i=history.length()-1;i>=0;i--){
   JSONObject rec=history.optJSONObject(i);if(rec==null)continue;
   JSONObject old=rec.optJSONObject("plan");int day=rec.optInt("day",-1);
   if(old==null||day<0||day>=old.getJSONArray("days").length())continue;
   int completed=index(plan,id(old,day));if(completed<0)continue;
   String saved=rec.optString("nextWorkoutId");if(index(plan,saved)>=0)return saved;
   return id(plan,(completed+1)%plan.getJSONArray("days").length());
  }
  return id(plan,selection>=0&&selection<plan.getJSONArray("days").length()?selection:0);
 }
 public static int opening(JSONObject plan,String next,int selection,boolean hasDraft) throws JSONException {
  return hasDraft&&selection>=0&&selection<plan.getJSONArray("days").length()?selection:index(plan,next);
 }
 public static void validateState(JSONObject plan,String next,int selection) throws JSONException {
  if(index(plan,next)<0||selection<0||selection>=plan.getJSONArray("days").length())throw new JSONException("Sequência inválida");
 }
}
