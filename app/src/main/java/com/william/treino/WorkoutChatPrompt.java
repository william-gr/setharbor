package com.william.treino;

import org.json.*;

public final class WorkoutChatPrompt {
 private WorkoutChatPrompt() {}
 public static final String GUIDE_URL="https://william-gr.github.io/setharbor/chatgpt/";
 public static String create(JSONObject plan,boolean includeCurrentPlan) throws Exception {
  WorkoutPlan.validate(plan);
  String request="Quero "+(includeCurrentPlan?"revisar minha ficha":"criar uma ficha nova")+" no SetHarbor. Leia as instruções e o catálogo em "+GUIDE_URL
   +" Pergunte meus objetivos, frequência e equipamentos antes de criar. Organize treinos cíclicos A/B/C, sem dias fixos. Entregue um link clicável Abrir no SetHarbor, sem copiar JSON nem importar arquivo. "
   +"Se não conseguir consultar a página ou gerar o link corretamente, avise; não invente IDs ou codificação. Revisão atual: "+plan.getLong("revision")+".";
  if(!includeCurrentPlan)return request;
  // Share only the plan contract, never arbitrary imported metadata.
  JSONObject context=new JSONObject();for(String key:new String[]{"format","schemaVersion","revision","title"})context.put(key,plan.get(key));
  JSONArray days=new JSONArray(),sourceDays=plan.getJSONArray("days");
  for(int d=0;d<sourceDays.length();d++){
   JSONObject day=sourceDays.getJSONObject(d),cleanDay=new JSONObject();for(String key:new String[]{"id","name"})cleanDay.put(key,day.get(key));
   if(day.has("focus"))cleanDay.put("focus",day.getString("focus"));
   JSONArray exercises=new JSONArray(),sourceExercises=day.getJSONArray("exercises");
   for(int e=0;e<sourceExercises.length();e++){
    JSONObject item=sourceExercises.getJSONObject(e),cleanItem=new JSONObject();for(String key:new String[]{"id","name","sets","reps"})cleanItem.put(key,item.get(key));
    if(item.has("catalogId"))cleanItem.put("catalogId",item.getString("catalogId"));exercises.put(cleanItem);
   }
   days.put(cleanDay.put("exercises",exercises));
  }
  context.put("days",days);
  return request+"\n\nFicha atual:\n"+context;
 }
}
