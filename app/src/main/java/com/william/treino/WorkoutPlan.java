package com.william.treino;
import org.json.*;
import java.util.*;
public final class WorkoutPlan {
 public static void validate(JSONObject plan) throws Exception {
  if(!"meu-treino-plan".equals(plan.getString("format"))||plan.getInt("schemaVersion")!=1)throw new Exception("Formato incompatível");
  if(plan.getLong("revision")<1)throw new Exception("Revisão inválida");
  bounded(plan.getString("title"),120);
  JSONArray days=plan.getJSONArray("days");if(days.length()<1||days.length()>7)throw new Exception("Use entre 1 e 7 dias");
  Set<String> dayIds=new HashSet<>(),exerciseIds=new HashSet<>();
  for(int d=0;d<days.length();d++){JSONObject day=days.getJSONObject(d);String id=day.getString("id");bounded(id,80);if(!dayIds.add(id))throw new Exception("Dias duplicados");bounded(day.getString("name"),80);if(day.has("focus"))bounded(day.getString("focus"),200);JSONArray exercises=day.getJSONArray("exercises");if(exercises.length()<1||exercises.length()>20)throw new Exception("Use entre 1 e 20 exercícios por dia");for(int e=0;e<exercises.length();e++){JSONObject ex=exercises.getJSONObject(e);String eid=ex.getString("id");bounded(eid,80);if(!exerciseIds.add(eid))throw new Exception("IDs de exercícios duplicados");bounded(ex.getString("name"),120);bounded(ex.getString("reps"),40);int sets=ex.getInt("sets");if(sets<1||sets>10)throw new Exception("Use entre 1 e 10 séries");}}
 }
 static void bounded(String value,int limit) throws Exception {if(value.trim().isEmpty()||value.length()>limit)throw new Exception("Texto vazio ou muito longo");}
}
