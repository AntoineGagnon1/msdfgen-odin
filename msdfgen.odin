package msdfgen

import "core:c"

when ODIN_OS == .Windows {
    foreign import msdfgen "msdfgen-c.lib"
}


// ---Core---
Vector2 :: distinct [2]c.double

Range :: struct {
    lower, upper : c.double
}

symmetricalRange :: proc(symmetricalWidth : c.double) -> Range { return { -.5 * symmetricalWidth, .5 * symmetricalWidth }; }

Projection :: struct {
    scale, translate : Vector2
}

/// Linear transformation of signed distance values.
DistanceMapping :: struct {
    scale, translate : c.double
}

distanceMappingFromRange :: proc(range : Range) -> DistanceMapping { return {1.0 / (range.upper - range.lower), -range.lower}; }
symmetricalDistanceMapping :: proc(symmetricalWidth : c.double) -> DistanceMapping { return distanceMappingFromRange(symmetricalRange(symmetricalWidth)); }

/**
  * Full signed distance field transformation specifies both spatial transformation (Projection)
  * as well as distance value transformation (DistanceMapping).
  */
SDFTransformation :: struct {
    projection : Projection,
    distanceMapping : DistanceMapping,
}

GeneratorConfig :: struct {
    /// Specifies whether to use the version of the algorithm that supports overlapping contours with the same winding. May be set to false to improve performance when no such contours are present.
    overlapSupport: bool,
}

Default_GeneratorConfig :: GeneratorConfig{true}

/// Mode of operation.
Mode :: enum c.int {
    /// Skips error correction pass.
    DISABLED,
    /// Corrects all discontinuities of the distance field regardless if edges are adversely affected.
    INDISCRIMINATE,
    /// Corrects artifacts at edges and other discontinuous distances only if it does not affect edges or corners.
    EDGE_PRIORITY,
    /// Only corrects artifacts at edges.
    EDGE_ONLY
}

DistanceCheckMode :: enum c.int {
    /// Never computes exact shape distance.
    DO_NOT_CHECK_DISTANCE,
    /// Only computes exact shape distance at edges. Provides a good balance between speed and precision.
    CHECK_DISTANCE_AT_EDGE,
    /// Computes and compares the exact shape distance for each suspected artifact.
    ALWAYS_CHECK_DISTANCE
}

ErrorCorrectionConfig :: struct {
    mode: Mode,
    distanceCheckMode: DistanceCheckMode,
    /// The minimum ratio between the actual and maximum expected distance delta to be considered an error.
    minDeviationRatio: c.double,
    /// The minimum ratio between the pre-correction distance error and the post-correction distance error. Has no effect for DO_NOT_CHECK_DISTANCE.
    minImproveRatio: c.double,
    /// An optional buffer to avoid dynamic allocation. Must have at least as many bytes as the MSDF has pixels.
    buffer: [^]u8,
}

Default_ErrorCorrectionConfig :: ErrorCorrectionConfig{.EDGE_PRIORITY, .CHECK_DISTANCE_AT_EDGE, 1.11111111111111111, 1.11111111111111111, nil}

MSDFGeneratorConfig :: struct {
    /// Specifies whether to use the version of the algorithm that supports overlapping contours with the same winding. May be set to false to improve performance when no such contours are present.
    overlap_support: bool,
    errorCorrection: ErrorCorrectionConfig,
}

Default_MSDFGeneratorConfig :: MSDFGeneratorConfig{true, Default_ErrorCorrectionConfig}

BitmapRef :: struct($Type: typeid, $N: u32) {
	pixels: [^]Type,
    width: c.int,
    height: c.int,
}

Shape :: distinct rawptr

ShapeBounds :: struct {
    l, b, r, t: c.double
}

@(default_calling_convention = "c", link_prefix = "msdfgen_")
foreign msdfgen {
    generateSDF :: proc(#by_ptr output: BitmapRef(c.float, 1), shape: Shape, #by_ptr transformation: SDFTransformation, #by_ptr config: GeneratorConfig = Default_GeneratorConfig) ---
    
    /// Generates a single-channel signed pseudo-distance field.
    generatePSDF :: proc(#by_ptr output: BitmapRef(c.float, 1), shape: Shape, #by_ptr transformation: SDFTransformation, #by_ptr config: GeneratorConfig = Default_GeneratorConfig) ---
    
    /// Generates a multi-channel signed distance field. Edge colors must be assigned first! (See edgeColoringSimple)
    generateMSDF :: proc(#by_ptr output: BitmapRef(c.float, 3), shape: Shape, #by_ptr transformation: SDFTransformation, #by_ptr config: MSDFGeneratorConfig = Default_MSDFGeneratorConfig) ---

    /// Generates a multi-channel signed distance field with true distance in the alpha channel. Edge colors must be assigned first.
    generateMTSDF :: proc(#by_ptr output: BitmapRef(c.float, 4), shape: Shape, #by_ptr transformation: SDFTransformation, #by_ptr config: MSDFGeneratorConfig = Default_MSDFGeneratorConfig) ---

    // Original simpler versions of the previous functions, which work well under normal circumstances, but cannot deal with overlapping contours.
    generateSDF_legacy :: proc(#by_ptr output: BitmapRef(c.float, 1), shape: Shape, range: Range, scale: Vector2, translate: Vector2) ---
    generatePSDF_legacy :: proc(#by_ptr output: BitmapRef(c.float, 1), shape: Shape, range: Range, scale: Vector2, translate: Vector2) ---
    generatePseudoSDF_legacy :: proc(#by_ptr output: BitmapRef(c.float, 1), shape: Shape, range: Range, scale: Vector2, translate: Vector2) ---
    generateMSDF_legacy :: proc(#by_ptr output: BitmapRef(c.float, 3), shape: Shape, range: Range, scale: Vector2, translate: Vector2, #by_ptr errorCorrectionConfig: ErrorCorrectionConfig = Default_ErrorCorrectionConfig) ---
    generateMTSDF_legacy :: proc(#by_ptr output: BitmapRef(c.float, 4), shape: Shape, range: Range, scale: Vector2, translate: Vector2, #by_ptr errorCorrectionConfig: ErrorCorrectionConfig = Default_ErrorCorrectionConfig) ---


    // Shape.h
    createShape :: proc() -> Shape ---
    destroyShape :: proc(shape: Shape) ---
    
    normalizeShape :: proc(shape: Shape) ---
    setShapeInverseYAxis :: proc(shape: Shape, inverseYAxis: bool) ---
    getShapeBounds :: proc(shape: Shape, border: c.double = 0, miterLimit: c.double = 0, polarity: c.int = 0) -> ShapeBounds ---
    shapeOrientContours :: proc(shape: Shape) ---

    // edge-coloring.h
    /** Assigns colors to edges of the shape in accordance to the multi-channel distance field technique.
    *  May split some edges if necessary.
    *  angleThreshold specifies the maximum angle (in radians) to be considered a corner, for example 3 (~172 degrees).
    *  Values below 1/2 PI will be treated as the external angle.
    */
    edgeColoringSimple :: proc(shape: Shape, angleThreshold: c.double, seed: c.ulonglong = 0) ---

    /** The alternative "ink trap" coloring strategy is designed for better results with typefaces
    *  that use ink traps as a design feature. It guarantees that even if all edges that are shorter than
    *  both their neighboring edges are removed, the coloring remains consistent with the established rules.
    */
    edgeColoringInkTrap :: proc(shape: Shape, angleThreshold: c.double, seed: c.ulonglong = 0) ---

    /** The alternative coloring by distance tries to use different colors for edges that are close together.
    *  This should theoretically be the best strategy on average. However, since it needs to compute the distance
    *  between all pairs of edges, and perform a graph optimization task, it is much slower than the rest.
    */
    edgeColoringByDistance :: proc(shape: Shape, angleThreshold: c.double, seed: c.ulonglong = 0) ---
}

// ---Ext---
unicode_t :: distinct c.uint
FreetypeHandle :: distinct rawptr
FontHandle :: distinct rawptr
GlyphIndex :: distinct c.uint

/// Global metrics of a typeface (in font units).
FontMetrics :: struct {
	/// The size of one EM.
	emSize: c.double,
	/// The vertical position of the ascender and descender relative to the baseline.
	ascenderY: c.double, 
    descenderY: c.double,
	/// The vertical difference between consecutive baselines.
	lineHeight: c.double,
	/// The vertical position and thickness of the underline.
	underlineY: c.double, 
    underlineThickness: c.double,
}

/// A structure to model a given axis of a variable font.
FontVariationAxis :: struct {
	/// The name of the variation axis.
	name: cstring,
	/// The axis's minimum coordinate value.
	minValue: c.double,
	/// The axis's maximum coordinate value.
	maxValue: c.double,
	/// The axis's default coordinate value. FreeType computes meaningful default values for Adobe MM fonts.
	defaultValue: c.double,
}

FontCoordinateScaling :: enum c.int {
    /// The coordinates are kept as the integer values native to the font file
    FONT_SCALING_NONE,
    /// The coordinates will be normalized to the em size, i.e. 1 = 1 em
    FONT_SCALING_EM_NORMALIZED,
    /// The incorrect legacy version that was in effect before version 1.12, coordinate values are divided by 64 - DO NOT USE - for backwards compatibility only
    FONT_SCALING_LEGACY
}

@(default_calling_convention="c", link_prefix = "msdfgen_")
foreign msdfgen {

    // resolve-shape-geometry.h
    /// Resolves any intersections within the shape by subdividing its contours using the Skia library and makes sure its contours have a consistent winding.
    resolveShapeGeometry :: proc(shape: Shape) -> bool ---

    // save-png.h
    /// Saves the bitmap as a PNG file.
    savePng_r8 :: proc(#by_ptr bitmap: BitmapRef(u8, 1), filename: cstring) ---
    savePng_rgb8 :: proc(#by_ptr bitmap: BitmapRef(u8, 3), filename: cstring) ---
    savePng_rgba8 :: proc(#by_ptr bitmap: BitmapRef(u8, 4), filename: cstring) ---
    savePng_r :: proc(#by_ptr bitmap: BitmapRef(c.float, 1), filename: cstring) ---
    savePng_rgb :: proc(#by_ptr bitmap: BitmapRef(c.float, 3), filename: cstring) ---
    savePng_rgba :: proc(#by_ptr bitmap: BitmapRef(c.float, 4), filename: cstring) ---

    // import-svg.h
    SVG_IMPORT_FAILURE : c.int
    SVG_IMPORT_SUCCESS_FLAG : c.int
    SVG_IMPORT_PARTIAL_FAILURE_FLAG : c.int
    SVG_IMPORT_INCOMPLETE_FLAG : c.int
    SVG_IMPORT_UNSUPPORTED_FEATURE_FLAG : c.int
    SVG_IMPORT_TRANSFORMATION_IGNORED_FLAG : c.int

    /// Builds a shape from an SVG path string
    buildShapeFromSvgPath :: proc(shape: Shape, pathDef: cstring, endpointSnapRange: c.double) -> bool ---

    /// Reads a single <path> element found in the specified SVG file and converts it to output Shape
    loadSvgShape :: proc(output: Shape, filename: cstring, pathIndex: c.int, dimensions: ^Vector2) -> bool ---

    /// New version - if Skia is available, reads the entire geometry of the SVG file into the output Shape, otherwise may only read one path, returns SVG import flags
    loadSvgShape_skia :: proc(output: Shape, viewBox: ^ShapeBounds, filename: cstring) -> c.int ---
    
    // import-font.h
    /// Initializes the FreeType library.
    initializeFreetype :: proc() -> FreetypeHandle ---
    /// Deinitializes the FreeType library.
    deinitializeFreetype :: proc(library: FreetypeHandle) ---

    /// Loads a font file and returns its handle.
    loadFont :: proc(library: FreetypeHandle, filename: cstring) -> FontHandle ---
    /// Loads a font from binary data and returns its handle.
    loadFontData :: proc(library: FreetypeHandle, data: [^]u8, length: c.int) -> FontHandle ---
    /// Unloads a font file.
    destroyFont :: proc(font: FontHandle) ---

    /// Outputs the metrics of a font file.
    getFontMetrics :: proc(metrics: ^FontMetrics, font: FontHandle, coordinateScaling: FontCoordinateScaling) -> bool ---
    /// Outputs the width of the space and tab characters.
    getFontWhitespaceWidth :: proc(spaceAdvance: ^c.double, tabAdvance: ^c.double, font: FontHandle, coordinateScaling: FontCoordinateScaling) -> bool ---
    /// Outputs the total number of glyphs available in the font.
	getGlyphCount :: proc(output: ^c.uint, font: FontHandle) -> bool ---
    /// Outputs the glyph index corresponding to the specified Unicode character.
    getGlyphIndex :: proc(glyphIndex: ^GlyphIndex, font: FontHandle, unicode: unicode_t) -> bool ---
    /// Loads the geometry of a glyph from a font file.
    loadGlyph :: proc(output: Shape, font: FontHandle, glyphIndex: GlyphIndex, coordinateScaling: FontCoordinateScaling, advance: ^c.double = nil) -> bool ---
    loadGlyph_unicode :: proc(output: Shape, font: FontHandle, unicode: unicode_t, coordinateScaling: FontCoordinateScaling, advance: ^c.double = nil) -> bool ---
    /// Outputs the kerning distance adjustment between two specific glyphs.
    getKerning :: proc(output: ^c.double, font: FontHandle, glyphIndex1: GlyphIndex, glyphIndex2: GlyphIndex, coordinateScaling: FontCoordinateScaling) -> bool ---
    getKerning_unicode :: proc(output: ^c.double, font: FontHandle, unicode1: unicode_t, unicode2: unicode_t, coordinateScaling: FontCoordinateScaling) -> bool ---
}