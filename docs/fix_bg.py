from PIL import Image
import sys

image_path = 'docs/arquitectura.png'
try:
    image = Image.open(image_path)
    # Check if image has alpha channel
    if image.mode in ('RGBA', 'LA') or (image.mode == 'P' and 'transparency' in image.info):
        # Create a new white background image
        bg = Image.new("RGB", image.size, (255, 255, 255))
        # Paste the original image on the background using the alpha channel as a mask
        bg.paste(image, mask=image.split()[3])
        bg.save(image_path)
        print("Fondo blanco añadido exitosamente.")
    else:
        print("La imagen no tiene fondo transparente.")
except Exception as e:
    print(f"Error: {e}")
