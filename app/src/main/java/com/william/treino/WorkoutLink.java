package com.william.treino;

import java.net.URI;
import java.nio.ByteBuffer;
import java.nio.charset.StandardCharsets;
import java.util.Base64;
import org.json.JSONObject;

/** Offline transport: the fragment never needs a plan download or remote lookup. */
public final class WorkoutLink {
 public static final String WEB_BASE="https://william-gr.github.io/setharbor/open/";
 public static final String APP_BASE="setharbor://workout";
 public static final int MAX_LENGTH=64000;
 private WorkoutLink() {}
 public static JSONObject parse(String address) throws Exception {
  if(address==null||address.length()>MAX_LENGTH)throw new Exception("Link ausente ou muito grande");
  URI uri=new URI(address);
  boolean web="https".equals(uri.getScheme())&&"william-gr.github.io".equals(uri.getHost())&&"/setharbor/open/".equals(uri.getPath());
  boolean app="setharbor".equals(uri.getScheme())&&"workout".equals(uri.getHost())&&"".equals(uri.getPath());
  if(!(web||app)||uri.getPort()!=-1||uri.getRawUserInfo()!=null||uri.getRawQuery()!=null)throw new Exception("Destino do link inválido");
  String fragment=uri.getRawFragment();
  if(fragment==null||!fragment.startsWith("v1."))throw new Exception("Versão do link inválida");
  String encoded=fragment.substring(3);
  if(encoded.isEmpty()||!encoded.matches("[A-Za-z0-9_-]+"))throw new Exception("Conteúdo do link inválido");
  byte[] bytes=Base64.getUrlDecoder().decode(encoded);
  String json=StandardCharsets.UTF_8.newDecoder().decode(ByteBuffer.wrap(bytes)).toString();
  JSONObject plan=new JSONObject(json);WorkoutPlan.validate(plan);return plan;
 }
 public static String encode(JSONObject plan) throws Exception {
  WorkoutPlan.validate(plan);
  String address=WEB_BASE+"#v1."+Base64.getUrlEncoder().withoutPadding().encodeToString(plan.toString().getBytes(StandardCharsets.UTF_8));
  if(address.length()>MAX_LENGTH)throw new Exception("Ficha muito grande para um link");
  return address;
 }
}
