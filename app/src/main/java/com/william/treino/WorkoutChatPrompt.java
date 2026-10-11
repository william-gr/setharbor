package com.william.treino;

import org.json.*;

public final class WorkoutChatPrompt {
 private WorkoutChatPrompt() {}
 public static String create(JSONObject plan,JSONObject catalog) throws Exception {
  WorkoutPlan.validate(plan);
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
  JSONArray choices=new JSONArray(),items=catalog.getJSONArray("exercises");
  for(int i=0;i<items.length();i++){
   JSONObject item=items.getJSONObject(i);
   choices.put(new JSONObject().put("catalogId",item.getString("id")).put("name",item.getJSONObject("name").getString("pt")).put("equipment",item.getJSONArray("equipment")));
  }
  return "Quero planejar meus treinos no SetHarbor. Pergunte meus objetivos, dias disponíveis e equipamentos antes de criar a ficha. "
   +"Use o catálogo abaixo; preserve IDs de posições existentes apenas quando o movimento continuar igual. Não há histórico ou cargas neste contexto. "
   +"Entregue um link clicável [Abrir no SetHarbor](URL), sem pedir copiar JSON ou importar arquivo. "
   +"A ficha JSON exige format=meu-treino-plan, schemaVersion=1, revision inteiro positivo maior que a revisão atual, title (até 120 caracteres), days (1–7). "
   +"Cada dia: id único (até 80), name (até 80), focus opcional não vazio (até 200), exercises (1–20). "
   +"Cada exercício: id único na ficha (até 80), catalogId do catálogo, name (até 120), sets inteiro 1–10, reps texto (até 40). "
   +"Use uma ferramenta de execução de código para gerar a URL exatamente; não invente a codificação. "
   +"Python: import json,base64; payload=base64.urlsafe_b64encode(json.dumps(plan,ensure_ascii=False,separators=(',',':')).encode('utf-8')).decode().rstrip('='); "
   +"url='"+WorkoutLink.WEB_BASE+"#v1.'+payload. URL no máximo "+WorkoutLink.MAX_LENGTH+" caracteres. "
   +"Se não puder executar a codificação, explique essa limitação em vez de fornecer um link inválido.\n\nFicha atual:\n"+context+"\n\nCatálogo:\n"+choices;
 }
}
