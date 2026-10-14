package com.william.treino;
import org.json.*;
import org.junit.Test;
import static org.junit.Assert.*;

public class WorkoutSequenceTest {
 JSONObject plan(String... ids) throws Exception {JSONArray days=new JSONArray();for(String id:ids)days.put(new JSONObject().put("id",id));return new JSONObject().put("days",days);}
 JSONObject record(JSONObject plan,int day) throws Exception {return new JSONObject().put("plan",plan).put("day",day);}
 @Test public void opaqueIdentifiersRoundTripWithoutXmlControlCharacters() {
  for(String id:new String[]{"normal","[\"x\"]","a"+(char)0+(char)1+" & < \" ☕\r\n"}){
   String encoded=WorkoutSequence.encodeId(id);assertEquals(id,WorkoutSequence.decodeId(encoded));assertFalse(encoded.contains(String.valueOf((char)0)));assertFalse(encoded.contains("\r"));
  }
  for(String invalid:new String[]{"[]","[1]","[null]","[\"a\",\"b\"]","broken"})assertEquals("",WorkoutSequence.decodeId(invalid));
 }
 @Test public void cyclesWrapAndExtrasDoNotMoveCursor() throws Exception {
  for(int size:new int[]{1,2,7}){String[] ids=new String[size];for(int i=0;i<size;i++)ids[i]="id"+i;JSONObject p=plan(ids);String next=ids[0];for(int i=0;i<size;i++){assertEquals(i,WorkoutSequence.index(p,next));next=WorkoutSequence.afterSave(p,next,i);}assertEquals(ids[0],next);}
  JSONObject p=plan("a","b","c");assertEquals("b",WorkoutSequence.afterSave(p,"b",0));assertEquals("b",WorkoutSequence.afterSave(p,"b",2));assertEquals("c",WorkoutSequence.afterSave(p,"b",1));assertThrows(JSONException.class,()->WorkoutSequence.afterSave(p,"missing",0));
  assertEquals("Treino A",WorkoutSequence.label(0));assertEquals("Treino G",WorkoutSequence.label(6));
 }
 @Test public void reorderPreservesIdAndRemovalStartsFirst() throws Exception {
  JSONObject p=plan("c","b","a");assertTrue(WorkoutSequence.related(p,plan("b","new")));assertFalse(WorkoutSequence.related(p,plan("other")));assertEquals("b",WorkoutSequence.revised(p,"b"));assertEquals("a",WorkoutSequence.afterSave(p,"b",1));assertEquals("c",WorkoutSequence.revised(p,"missing"));
 }
 @Test public void migrationUsesSnapshotsAndValidSelection() throws Exception {
  JSONObject p=plan("a","b","c");assertEquals("a",WorkoutSequence.migrate(p,new JSONArray(),-1));assertEquals("a",WorkoutSequence.migrate(p,new JSONArray(),3));assertEquals("c",WorkoutSequence.migrate(p,new JSONArray(),2));
  JSONArray h=new JSONArray().put(record(p,2));assertEquals("a",WorkoutSequence.migrate(p,h,1));
  h.put(JSONObject.NULL).put(new JSONObject()).put(record(p,-1)).put(record(p,3)).put(record(plan("other"),0));assertEquals("a",WorkoutSequence.migrate(p,h,1));
  h.put(record(plan("c","b","a"),1));assertEquals("c",WorkoutSequence.migrate(p,h,0));
  assertEquals("c",WorkoutSequence.migrate(p,new JSONArray().put(record(plan("a","b"),1)),0));
  assertEquals("b",WorkoutSequence.migrate(p,new JSONArray().put(record(p,0)).put(record(plan("a","removed"),1)),0));
  h.put(record(p,0).put("nextWorkoutId","c"));assertEquals("c",WorkoutSequence.migrate(p,h,0));
 }
 @Test public void openingResumesDraftOtherwiseSuggestsCursorAndBackupRejectsInvalidState() throws Exception {
  JSONObject p=plan("a","b");assertEquals(0,WorkoutSequence.opening(p,"b",0,true));assertEquals(1,WorkoutSequence.opening(p,"b",0,false));assertEquals(1,WorkoutSequence.opening(p,"b",-1,true));assertEquals(1,WorkoutSequence.opening(p,"b",2,true));
  WorkoutSequence.validateState(p,"b",0);assertThrows(JSONException.class,()->WorkoutSequence.validateState(p,"unknown",0));assertThrows(JSONException.class,()->WorkoutSequence.validateState(p,"a",-1));assertThrows(JSONException.class,()->WorkoutSequence.validateState(p,"a",2));
 }
}
