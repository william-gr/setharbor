package com.william.treino;

/** Blank means unrecorded, never zero. Completion is tracked separately. */
public final class WorkoutSet {
 private WorkoutSet() {}
 public static void validate(String kg,String reps) {
  kg=kg.trim();reps=reps.trim();
  if(!kg.isEmpty()){
   double weight=Double.parseDouble(kg.replace(',','.'));
   if(weight<0||!Double.isFinite(weight))throw new IllegalArgumentException("Carga inválida");
  }
  if(!reps.isEmpty()&&Integer.parseInt(reps)<=0)throw new IllegalArgumentException("Repetições inválidas");
 }
 public static String summary(String kg,String reps) {
  kg=kg.trim();reps=reps.trim();
  if(kg.isEmpty()&&reps.isEmpty())return "Série concluída · sem carga/repetições registradas";
  if(kg.isEmpty())return reps+" reps · carga não registrada";
  if(reps.isEmpty())return kg+" kg · repetições não registradas";
  return kg+" kg × "+reps;
 }
}
