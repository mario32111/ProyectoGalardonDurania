import sys
import json
from ultralytics import YOLO

def main():
    # Verificar si se pasó el argumento con la ruta de la imagen
    if len(sys.argv) < 2:
        print(json.dumps({"error": "Falta la ruta de la imagen."}))
        sys.exit(1)

    image_path = sys.argv[1]

    try:
        # Cargar el modelo YOLO
        model = YOLO('best.pt')

        # Ejecutar inferencia
        # verbose=False para no ensuciar el stdout con logs de ultralytics
        # conf=0.15 para que sea más sensible y detecte las vacas incluso si no está tan seguro
        results = model(image_path, verbose=False, conf=0.03)
        
        # Diccionario para contar las clases detectadas
        class_counts = {}
        names = model.names
        
        for result in results:
            for box in result.boxes:
                class_id = int(box.cls[0].item())
                class_name = names[class_id]
                class_counts[class_name] = class_counts.get(class_name, 0) + 1

        # Lógica heurística para encontrar las vacas paradas y acostadas según el nombre de la clase
        vacas_acostadas = 0
        vacas_paradas = 0

        for name, count in class_counts.items():
            name_lower = name.lower()
            if 'acostada' in name_lower or 'echada' in name_lower or 'lying' in name_lower or name_lower == '0':
                vacas_acostadas += count
            elif 'parada' in name_lower or 'pie' in name_lower or 'standing' in name_lower or name_lower == '1':
                vacas_paradas += count

        # Si no se encontraron por nombres específicos y solo hay 2 clases desconocidas,
        # puede que las variables sigan en 0. 
        # Aquí se devuelve tanto el conteo heurístico como el detalle crudo de las clases.
        
        output = {
            "vacasAcostadas": vacas_acostadas,
            "vacasParadas": vacas_paradas,
            "detalles": class_counts
        }

        # Imprimir resultado en JSON para que NodeJS pueda leerlo fácilmente de stdout
        print(json.dumps(output))

    except Exception as e:
        print(json.dumps({"error": str(e)}))
        sys.exit(1)

if __name__ == '__main__':
    main()
