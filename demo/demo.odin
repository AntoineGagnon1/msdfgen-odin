package demo

import msdfgen "../"

main :: proc() {

	ft := msdfgen.initializeFreetype()
	assert(ft != nil)
	defer msdfgen.deinitializeFreetype(ft)
	
	font := msdfgen.loadFont(ft, "LiberationMono.ttf")
	assert(font != nil)
	defer msdfgen.destroyFont(font)

	shape := msdfgen.createShape()
	defer msdfgen.destroyShape(shape)

	assert(msdfgen.loadGlyph(shape, font, 'A'))
	msdfgen.normalizeShape(shape)
	msdfgen.edgeColoringSimple(shape, 3)
	
	msdf := [32 * 32 * 3]f32{}
	msdf_ref := msdfgen.BitmapRef(f32, 3){raw_data(&msdf), 32, 32}

	msdfgen.generateMSDF_old(msdf_ref, shape, 4, {1, 1}, {4, 4})
	msdfgen.savePng_rgb(msdf_ref, "output.png")
}