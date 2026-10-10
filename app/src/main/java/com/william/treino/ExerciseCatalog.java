package com.william.treino;

import org.json.*;
import java.text.Normalizer;
import java.util.*;

/** Bundled, offline reference data. Plan positions keep their own IDs. */
public final class ExerciseCatalog {
 private final Map<String, JSONObject> exercises = new LinkedHashMap<>();
 private final Map<String, String> aliases = new HashMap<>();
 private final Map<String, String> legacySlots = new HashMap<>();
 private final Map<String, Map<String, String>> terms = new HashMap<>();

 public ExerciseCatalog(JSONObject data) throws Exception {
  if (!"setharbor-exercise-catalog".equals(data.getString("format")) || data.getInt("schemaVersion") != 1) throw new Exception("Catálogo incompatível");
  for (String table : new String[]{"groups", "muscles", "equipment", "movementPatterns", "substitutionFamilies"}) {
   Map<String, String> labels = new LinkedHashMap<>();
   JSONArray rows = data.getJSONArray(table);
   for (int i=0; i<rows.length(); i++) {
    JSONObject row=rows.getJSONObject(i);
    if (labels.put(row.getString("id"), row.getJSONObject("name").getString("pt"))!=null) throw new Exception("Termo duplicado");
   }
   terms.put(table, labels);
  }
  JSONArray rows=data.getJSONArray("exercises");
  for (int i=0; i<rows.length(); i++) {
   JSONObject row=rows.getJSONObject(i);String id=row.getString("id");
   if (exercises.put(id,row)!=null) throw new Exception("Exercício duplicado");
   label("groups",row.getString("group"));label("movementPatterns",row.getString("movementPattern"));label("substitutionFamilies",row.getString("substitutionFamily"));
   for (String field : new String[]{"primaryMuscles", "secondaryMuscles", "stabilizerMuscles", "equipment"}) {
    JSONArray refs=row.getJSONArray(field);
    if ((field.equals("primaryMuscles")||field.equals("equipment")) && refs.length()==0) throw new Exception("Referência vazia");
    for(int j=0;j<refs.length();j++)label(field.equals("equipment")?"equipment":"muscles",refs.getString(j));
   }
   addAlias(row.getJSONObject("name").getString("pt"),id);addAlias(row.getJSONObject("name").getString("en"),id);
   JSONArray names=row.getJSONArray("aliases");for(int j=0;j<names.length();j++)addAlias(names.getString(j),id);
  }
 }
 private void addAlias(String name,String id) throws Exception {
  String previous=aliases.put(normalize(name),id);if(previous!=null&&!previous.equals(id))throw new Exception("Nome ambíguo: "+name);
 }
 static String normalize(String value) {return Normalizer.normalize(value.toLowerCase(Locale.ROOT),Normalizer.Form.NFD).replaceAll("\\p{M}","").trim();}
 public JSONObject get(String id) {return exercises.get(id);}
 public Collection<JSONObject> all() {return Collections.unmodifiableCollection(exercises.values());}
 public JSONObject resolve(JSONObject item) {
  // An explicit ID is authoritative, including references from future catalogs.
  if(item.has("catalogId"))return get(item.optString("catalogId"));
  String id=aliases.get(normalize(item.optString("name")));
  if(id==null)id=legacySlots.get(item.optString("id"));
  return get(id);
 }
 public void bindLegacyPlan(JSONObject original) throws JSONException {
  JSONArray days=original.getJSONArray("days");
  for(int d=0;d<days.length();d++) {
   JSONArray items=days.getJSONObject(d).getJSONArray("exercises");
   for(int e=0;e<items.length();e++){JSONObject item=items.getJSONObject(e);legacySlots.put(item.getString("id"),item.getString("catalogId"));}
  }
 }
 public String label(String table,String id) throws Exception {String value=terms.get(table).get(id);if(value==null)throw new Exception("Referência desconhecida: "+id);return value;}
 public String labels(String table,JSONArray ids) {
  ArrayList<String> values=new ArrayList<>();for(int i=0;i<ids.length();i++){try{values.add(label(table,ids.optString(i)));}catch(Exception err){throw new IllegalStateException(err);}}return String.join(", ",values);
 }
 public String name(JSONObject item) {return item.optJSONObject("name").optString("pt");}
 public boolean similar(JSONObject a,JSONObject b) {
  for(String field:new String[]{"group","substitutionFamily","movementPattern","mechanic"})if(!a.optString(field).equals(b.optString(field)))return false;
  return true;
 }
 public List<JSONObject> alternatives(JSONObject current) {
  List<JSONObject> result=new ArrayList<>();if(current==null)return result;
  for(JSONObject item:exercises.values())if(!item.optString("id").equals(current.optString("id"))&&similar(current,item)&&!"band".equals(item.optString("loadUnit"))&&!"isometric".equals(item.optString("mechanic")))result.add(item);
  return result;
 }
 public String loadHint(JSONObject item) {
  switch(item.optString("loadUnit")) {
   case "per-dumbbell":return "Carga por halter";
   case "per-side":return "Carga por lado";
   case "bodyweight":return "0 kg sem carga adicional";
   case "assistance":return "Assistência em kg · reduza para progredir";
   case "band":return "Resistência de elástico";
   default:return "Carga total em kg";
  }
 }
}
