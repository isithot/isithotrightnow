import imageio
import glob

for site in ['009021','014015','015590','023090','040842','066062','067105','070351','087031','094029']:

	animation = []
	files = "%s-ts-18*.png" %site

	for filename in sorted(glob.glob(files)):
		animation.append(imageio.imread(filename))

	imageio.mimwrite('%s-ts-18.mp4' %site, animation, format='mp4' , fps=15)