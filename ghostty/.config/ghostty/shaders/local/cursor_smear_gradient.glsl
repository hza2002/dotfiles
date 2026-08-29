/*
Based on cursor_smear_gradient.glsl from:
https://github.com/KroneCorylus/ghostty-shader-playground
Upstream revision: 2a39f0b404614277ce679e81d70dd6e62d3add6b
The upstream file credits PremModhaOfficial for the shader contribution.
Local changes tune the gradient, saturation, opacity, and blend behavior.

MIT License

Copyright (c) 2025 Krone Corylus

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
*/

// Cursor trail shader that creates a hexagonal trailing effect with gradient colors.

// Process each edge: compute distance and determine if point is inside
void processEdge(vec2 p, vec2 a, vec2 b, inout float minDist, inout float inside) {
    vec2 edge = b - a;
    vec2 pa = p - a;
    float lenSq = dot(edge, edge);
    if (lenSq <= 1e-12) {
        return;
    }
    float invLenSq = 1.0 / lenSq;

    float t = clamp(dot(pa, edge) * invLenSq, 0.0, 1.0);
    vec2 diff = pa - edge * t;
    minDist = min(minDist, dot(diff, diff));

    float cross = edge.x * pa.y - edge.y * pa.x;
    inside = min(inside, step(0.0, cross));
}

// Signed distance field for hexagon (negative inside, positive outside)
// Vertices must be in counter-clockwise order
float sdHexagon(in vec2 p, in vec2 v0, in vec2 v1, in vec2 v2, in vec2 v3, in vec2 v4, in vec2 v5) {
    float minDist = 1e20;
    float inside = 1.0;

    processEdge(p, v0, v1, minDist, inside);
    processEdge(p, v1, v2, minDist, inside);
    processEdge(p, v2, v3, minDist, inside);
    processEdge(p, v3, v4, minDist, inside);
    processEdge(p, v4, v5, minDist, inside);
    processEdge(p, v5, v0, minDist, inside);

    float dist = sqrt(max(minDist, 0.0));
    return mix(dist, -dist, inside);
}

// Signed distance field for rectangle (negative inside, positive outside)
float sdRectangle(in vec2 p, in vec2 center, in vec2 halfSize) {
    vec2 d = abs(p - center) - halfSize;
    return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
}

// Represents cursor as a quad with four corners
struct Quad {
    vec2 topLeft;
    vec2 topRight;
    vec2 bottomLeft;
    vec2 bottomRight;
};

// Construct quad from top-left position and size
Quad getQuad(vec2 pos, vec2 size) {
    Quad q;
    q.topLeft = pos;
    q.topRight = pos + vec2(size.x, 0.0);
    q.bottomLeft = pos - vec2(0.0, size.y);
    q.bottomRight = pos + vec2(size.x, -size.y);
    return q;
}

// Select 3 corners from quad based on movement direction
// sel.x: 0=left, 1=right | sel.y: 0=top, 1=bottom
// Returns corners in counter-clockwise order for hexagon construction
void selectTrailCorners(Quad q, vec2 sel, out vec2 p1, out vec2 p2, out vec2 p3) {
    p1 = mix(mix(q.topRight, q.topLeft, sel.x),
             mix(q.bottomRight, q.bottomLeft, sel.x),
             sel.y);

    p2 = mix(mix(q.topLeft, q.bottomLeft, sel.x),
             mix(q.topRight, q.bottomRight, sel.x),
             sel.y);
    p3 = mix(mix(q.bottomRight, q.topRight, sel.x),
             mix(q.bottomLeft, q.topLeft, sel.x),
             sel.y);

}

// Select 4 corners from quad based on movement direction
// sel.x: 0=left, 1=right | sel.y: 0=top, 1=bottom
// Returns corners in counter-clockwise order for hexagon construction
void selectCorners(Quad q, vec2 sel, out vec2 p1, out vec2 p2, out vec2 p3, out vec2 p4) {
    selectTrailCorners(q, sel, p1, p2, p3);

    p4 = mix(mix(q.bottomLeft, q.bottomRight, sel.x),
             mix(q.topLeft, q.topRight, sel.x),
             sel.y);
}

// Cubic ease-out function for smooth animation (expects clamped input)
float easeClamped(float x) {
    float t = 1.0 - x;
    return 1.0 - t * t * t;
}

// Generate gradient color based on position
vec3 gradientColor(float factor) {
    const vec3 yellow = vec3(0.980, 0.741, 0.184); // #fabd2f
    const vec3 aqua = vec3(0.557, 0.753, 0.486);   // #8ec07c
    const vec3 blue = vec3(0.612, 0.788, 0.922);   // #9cc9eb
    float t = mod(factor, 1.0);

    // Keep yellow as a brief accent; let aqua and blue carry the trail.
    if (t < 0.14) {
        return mix(yellow, aqua, smoothstep(0.0, 0.14, t));
    }
    if (t < 0.50) {
        return mix(aqua, blue, smoothstep(0.14, 0.50, t));
    }
    if (t < 0.86) {
        return mix(blue, aqua, smoothstep(0.50, 0.86, t));
    }
    return mix(aqua, yellow, smoothstep(0.86, 1.0, t));
}

// Trail animation duration in seconds
const float DURATION = 0.25;

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    // Calculate animation progress with easing
    float baseProgress = clamp((iTime - iTimeCursorChange) / DURATION, 0.0, 1.0);

    vec2 uv = fragCoord / iResolution.xy;
    vec4 background = texture(iChannel0, uv);

    // Skip further work when animation is complete
    if (baseProgress >= 1.0) {
        fragColor = background;
        return;
    }

    fragColor = background;

    // Precompute reused values
    float invResY = 1.0 / iResolution.y;
    float scale = 2.0 * invResY;
    float aaWidth = scale;
    vec2 normOffset = iResolution.xy * invResY;

    // Normalize cursor positions and sizes to screen-independent coordinates
    vec2 currentPos = iCurrentCursor.xy * scale - normOffset;
    vec2 previousPos = iPreviousCursor.xy * scale - normOffset;
    vec2 currentSize = iCurrentCursor.zw * scale;
    vec2 previousSize = iPreviousCursor.zw * scale;

    // Determine movement direction and construct cursor quads
    vec2 deltaPos = currentPos - previousPos;
    Quad currentCursor = getQuad(currentPos, currentSize);
    Quad previousCursor = getQuad(previousPos, previousSize);
    vec2 selector = step(vec2(0.0), deltaPos);

    // Select corners based on movement direction
    vec2 currP1, currP2, currP3, currP4;
    vec2 prevP1, prevP2, prevP3;
    selectCorners(currentCursor, selector, currP1, currP2, currP3, currP4);
    selectTrailCorners(previousCursor, selector, prevP1, prevP2, prevP3);

    float easedProgress = easeClamped(baseProgress);
    float stretchedProgress = min(baseProgress * 2.0, 1.0);
    float easedProgressDouble = easeClamped(stretchedProgress);

    // Create trailing effect by moving diagonal point slower
    vec2 trailP1 = mix(prevP1, currP1, easedProgress);
    vec2 trailP2 = mix(prevP2, currP2, easedProgressDouble);
    vec2 trailP3 = mix(prevP3, currP3, easedProgressDouble);

    // Compute hexagon SDF and convert to alpha with antialiasing
    vec2 normCoord = fragCoord * scale - normOffset;
    float sdfHex = sdHexagon(normCoord, trailP1, trailP2, currP2, currP4, currP3, trailP3);
    float alpha = 1.0 - smoothstep(-aaWidth, aaWidth, sdfHex);

    // Compute current cursor SDF
    vec2 halfCurrentSize = currentSize * 0.5;
    vec2 currentCenter = currentPos + vec2(halfCurrentSize.x, -halfCurrentSize.y);
    float sdfCurrentCursor = sdRectangle(normCoord, currentCenter, halfCurrentSize);

    // Generate gradient color
    float gradientFactor = (normCoord.y + 1.0) * 0.5; // Gradient across vertical position
    float timeComponent = sin(iTime); // Oscillates between -1 and 1
    vec3 trailColorVec3 = gradientColor(gradientFactor * timeComponent);
    vec4 trail = vec4(trailColorVec3, 0.82); // Set alpha for gradient trail

    // Enhance color saturation for more vibrant trail effect
    float gray = dot(trail.rgb, vec3(0.299, 0.587, 0.114));
    const float saturationBoost = 1.45;
    vec4 enhancedColor = clamp(
        mix(vec4(vec3(gray), trail.a), trail, saturationBoost),
        0.0, 1.0
    );

    // Blend trail color with background
    vec4 originalColor = fragColor;
    fragColor.rgb = mix(fragColor.rgb, enhancedColor.rgb, alpha * enhancedColor.a);

    // Remove trail where it overlaps with current cursor
    fragColor.rgb = mix(fragColor.rgb, originalColor.rgb, step(sdfCurrentCursor, 0.0));
}
