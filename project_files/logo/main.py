import os

for i in range(1, 50):
    command = f"docker run -v $(pwd):/imgs dpokidov/imagemagick /imgs/input.png -resize 500x500 -colorspace RGB -channel RGB -quantize RGB -colors {i} -dither FloydSteinberg +channel -colorspace sRGB /imgs/output_{i}.png"

    os.system(command)
