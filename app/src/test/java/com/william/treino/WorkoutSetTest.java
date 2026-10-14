package com.william.treino;

import org.junit.Test;
import static org.junit.Assert.*;

public class WorkoutSetTest {
 @Test public void omittedAndPartiallyRecordedValuesAreAccepted() {
  for(String[] values:new String[][]{{"",""},{"  "," "},{"","8"},{"42,5",""},{"0","8"},{" 20 "," 10 "}})WorkoutSet.validate(values[0],values[1]);
 }
 @Test public void enteredValuesMustStillBeValid() {
  for(String weight:new String[]{"-1","NaN","Infinity","abc","1.2.3"})assertThrows(IllegalArgumentException.class,()->WorkoutSet.validate(weight,""));
  for(String reps:new String[]{"0","-2","2.5","abc","2147483648"})assertThrows(IllegalArgumentException.class,()->WorkoutSet.validate("",reps));
 }
 @Test public void summariesDistinguishMissingDataFromZeroAndKeepLegacyDisplay() {
  assertEquals("Série concluída · sem carga/repetições registradas",WorkoutSet.summary(" ",""));
  assertEquals("8 reps · carga não registrada",WorkoutSet.summary("","8"));
  assertEquals("42,5 kg · repetições não registradas",WorkoutSet.summary("42,5",""));
  assertEquals("0 kg × 8",WorkoutSet.summary("0","8"));
  assertEquals("40 kg × 8",WorkoutSet.summary(" 40 ","8"));
 }
}
