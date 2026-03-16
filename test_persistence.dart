void main() {
  // Este script es una referencia de qué verificar para asegurar la persistencia.
  // En un dispositivo real o mediante herramientas de inspección, confirmar:
  // 
  // 1. SELECT COUNT(*) FROM categories; 
  //    -> Debería ser >= 25 (Todas las categorías de AppCategories).
  // 
  // 2. SELECT * FROM accounts; 
  //    -> Debería tener al menos 1 cuenta (Efectivo o Cuentas creadas).
  // 
  // 3. Guardado exitoso:
  //    -> Intentar guardar un gasto con ID de categoría alto (ej. 25).
}
