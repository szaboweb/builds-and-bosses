from PIL import Image

img = Image.open('fighter.png')
target_size = (128, 128)

# Arányos átméretezés, hogy beleférjen
img.thumbnail(target_size, Image.Resampling.LANCZOS)

# Új, 64x64-es átlátszó háttér létrehozása
new_img = Image.new('RGBA', target_size, (0, 0, 0, 0))

# A kicsinyített kép középre illesztése
paste_x = (target_size[0] - img.width) // 2
paste_y = (target_size[1] - img.height) // 2
new_img.paste(img, (paste_x, paste_y))

new_img.save('fighter_128x128_centered.png')
print('A kép középre igazítva és átméretezve!')