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

	assert(msdfgen.loadGlyph(shape, font, 'A', .FONT_SCALING_EM_NORMALIZED))
	msdfgen.normalizeShape(shape)
	msdfgen.edgeColoringSimple(shape, 3)
	
	msdf := [32 * 32 * 3]f32{}
	msdf_ref := msdfgen.BitmapRef(f32, 3){raw_data(&msdf), 32, 32}

	scale : msdfgen.Vector2 = { 32.0, 32.0 };
	translation : msdfgen.Vector2 = { 0.125, 0.125 };
	transform : msdfgen.SDFTransformation = { {scale, translation}, msdfgen.symmetricalDistanceMapping(0.125) };
	msdfgen.generateMSDF(msdf_ref, shape, transform);
	
	msdfgen.savePng_rgb(msdf_ref, "output.png")
}