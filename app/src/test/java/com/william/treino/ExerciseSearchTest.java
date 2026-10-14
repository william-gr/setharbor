package com.william.treino;

import java.net.*;
import org.junit.Test;
import static org.junit.Assert.*;

public class ExerciseSearchTest {
 @Test public void unicodeAndCustomNamesRemainOneGoogleQuery() throws Exception {
  for(String name:new String[]{"Supino reto barra","Flexão 💪 + café & # / ?","Custom exercise"}){
   URI uri=new URI(ExerciseSearch.url(name));assertEquals("https",uri.getScheme());assertEquals("www.google.com",uri.getHost());assertEquals("/search",uri.getPath());assertNull(uri.getFragment());
   assertEquals(name+" exercício execução correta",URLDecoder.decode(uri.getRawQuery().substring(2),"UTF-8"));
  }
 }
}
