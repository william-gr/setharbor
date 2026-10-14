package com.william.treino;

import java.net.URLEncoder;

public final class ExerciseSearch {
 private ExerciseSearch() {}
 public static String url(String name) throws java.io.UnsupportedEncodingException {
  return "https://www.google.com/search?q="+URLEncoder.encode(name+" exercício execução correta","UTF-8");
 }
}
