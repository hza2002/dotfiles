/*
Based on cursor_smear_gradient.glsl from:
https://github.com/KroneCorylus/ghostty-shader-playground
Upstream revision: 2a39f0b404614277ce679e81d70dd6e62d3add6b
The upstream file credits PremModhaOfficial for the shader contribution.
Local changes combine the cursor trail and shape echo into one bounded pass.

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

const float TRAIL_DURATION = 0.25;
const float BASE_GLOW_RADIUS = 10.0;
const float BASE_GLOW_STRENGTH = 0.24;
const float CURRENT_FLASH_DURATION = 0.16;
const float CURRENT_FLASH_RADIUS_BOOST = 5.0;
const float CURRENT_FLASH_STRENGTH_BOOST = 0.14;
const float SHAPE_ECHO_DURATION = 0.20;
const float SHAPE_ECHO_RADIUS = 4.0;
const float SHAPE_ECHO_STRENGTH = 0.28;
// At eight radii, the strongest halo contributes less than 0.013% opacity.
const float EFFECT_BOUNDS_PADDING =
    (BASE_GLOW_RADIUS + CURRENT_FLASH_RADIUS_BOOST) * 8.0;

struct Quad {
    vec2 topLeft;
    vec2 topRight;
    vec2 bottomLeft;
    vec2 bottomRight;
};

void processEdge(
    vec2 point,
    vec2 start,
    vec2 end,
    inout float minDistance,
    inout float inside
) {
    vec2 edge = end - start;
    vec2 relative = point - start;
    float lengthSquared = dot(edge, edge);
    if (lengthSquared <= 1e-12) {
        return;
    }

    float position = clamp(dot(relative, edge) / lengthSquared, 0.0, 1.0);
    vec2 difference = relative - edge * position;
    minDistance = min(minDistance, dot(difference, difference));
    inside = min(inside, step(0.0, edge.x * relative.y - edge.y * relative.x));
}

float hexagonDistance(
    vec2 point,
    vec2 v0,
    vec2 v1,
    vec2 v2,
    vec2 v3,
    vec2 v4,
    vec2 v5
) {
    float minDistance = 1e20;
    float inside = 1.0;
    processEdge(point, v0, v1, minDistance, inside);
    processEdge(point, v1, v2, minDistance, inside);
    processEdge(point, v2, v3, minDistance, inside);
    processEdge(point, v3, v4, minDistance, inside);
    processEdge(point, v4, v5, minDistance, inside);
    processEdge(point, v5, v0, minDistance, inside);
    float distance = sqrt(max(minDistance, 0.0));
    return mix(distance, -distance, inside);
}

float rectangleDistance(vec2 point, vec2 center, vec2 halfSize) {
    vec2 delta = abs(point - center) - halfSize;
    return length(max(delta, 0.0)) + min(max(delta.x, delta.y), 0.0);
}

Quad cursorQuad(vec2 position, vec2 size) {
    Quad quad;
    quad.topLeft = position;
    quad.topRight = position + vec2(size.x, 0.0);
    quad.bottomLeft = position - vec2(0.0, size.y);
    quad.bottomRight = position + vec2(size.x, -size.y);
    return quad;
}

void selectTrailCorners(
    Quad quad,
    vec2 selector,
    out vec2 p1,
    out vec2 p2,
    out vec2 p3
) {
    p1 = mix(
        mix(quad.topRight, quad.topLeft, selector.x),
        mix(quad.bottomRight, quad.bottomLeft, selector.x),
        selector.y
    );
    p2 = mix(
        mix(quad.topLeft, quad.bottomLeft, selector.x),
        mix(quad.topRight, quad.bottomRight, selector.x),
        selector.y
    );
    p3 = mix(
        mix(quad.bottomRight, quad.topRight, selector.x),
        mix(quad.bottomLeft, quad.topLeft, selector.x),
        selector.y
    );
}

void selectCorners(
    Quad quad,
    vec2 selector,
    out vec2 p1,
    out vec2 p2,
    out vec2 p3,
    out vec2 p4
) {
    selectTrailCorners(quad, selector, p1, p2, p3);
    p4 = mix(
        mix(quad.bottomLeft, quad.bottomRight, selector.x),
        mix(quad.topLeft, quad.topRight, selector.x),
        selector.y
    );
}

float easeOutCubic(float value) {
    float inverse = 1.0 - value;
    return 1.0 - inverse * inverse * inverse;
}

vec3 gradientColor(float factor) {
    const vec3 yellow = vec3(0.980, 0.741, 0.184);
    const vec3 aqua = vec3(0.557, 0.753, 0.486);
    const vec3 blue = vec3(0.612, 0.788, 0.922);
    float position = mod(factor, 1.0);

    if (position < 0.14) {
        return mix(yellow, aqua, smoothstep(0.0, 0.14, position));
    }
    if (position < 0.50) {
        return mix(aqua, blue, smoothstep(0.14, 0.50, position));
    }
    if (position < 0.86) {
        return mix(blue, aqua, smoothstep(0.50, 0.86, position));
    }
    return mix(aqua, yellow, smoothstep(0.86, 1.0, position));
}

vec2 cursorCenter(vec4 cursor) {
    return cursor.xy + vec2(cursor.z * 0.5, -cursor.w * 0.5);
}

bool outsideEffectBounds(vec2 point, float elapsed) {
    vec2 currentMin = iCurrentCursor.xy + vec2(0.0, -iCurrentCursor.w);
    vec2 currentMax = iCurrentCursor.xy + vec2(iCurrentCursor.z, 0.0);
    vec2 lower = currentMin;
    vec2 upper = currentMax;

    if (elapsed < TRAIL_DURATION) {
        vec2 previousMin = iPreviousCursor.xy + vec2(0.0, -iPreviousCursor.w);
        vec2 previousMax = iPreviousCursor.xy + vec2(iPreviousCursor.z, 0.0);
        lower = min(lower, previousMin);
        upper = max(upper, previousMax);
    }

    lower -= vec2(EFFECT_BOUNDS_PADDING);
    upper += vec2(EFFECT_BOUNDS_PADDING);
    return any(lessThan(point, lower)) || any(greaterThan(point, upper));
}

vec4 applyTrail(vec4 terminal, vec2 fragCoord, float elapsed) {
    float progress = clamp(elapsed / TRAIL_DURATION, 0.0, 1.0);
    if (progress >= 1.0) {
        return terminal;
    }

    float inverseResolutionY = 1.0 / iResolution.y;
    float scale = 2.0 * inverseResolutionY;
    float antialiasWidth = scale;
    vec2 normalizedOffset = iResolution.xy * inverseResolutionY;
    vec2 currentPosition = iCurrentCursor.xy * scale - normalizedOffset;
    vec2 previousPosition = iPreviousCursor.xy * scale - normalizedOffset;
    vec2 currentSize = iCurrentCursor.zw * scale;
    vec2 previousSize = iPreviousCursor.zw * scale;
    vec2 selector = step(vec2(0.0), currentPosition - previousPosition);
    Quad current = cursorQuad(currentPosition, currentSize);
    Quad previous = cursorQuad(previousPosition, previousSize);

    vec2 currentP1, currentP2, currentP3, currentP4;
    vec2 previousP1, previousP2, previousP3;
    selectCorners(current, selector, currentP1, currentP2, currentP3, currentP4);
    selectTrailCorners(previous, selector, previousP1, previousP2, previousP3);

    float easedProgress = easeOutCubic(progress);
    float fastProgress = easeOutCubic(min(progress * 2.0, 1.0));
    vec2 trailP1 = mix(previousP1, currentP1, easedProgress);
    vec2 trailP2 = mix(previousP2, currentP2, fastProgress);
    vec2 trailP3 = mix(previousP3, currentP3, fastProgress);
    vec2 normalizedCoord = fragCoord * scale - normalizedOffset;
    float trailDistance = hexagonDistance(
        normalizedCoord,
        trailP1,
        trailP2,
        currentP2,
        currentP4,
        currentP3,
        trailP3
    );
    float alpha = 1.0 - smoothstep(-antialiasWidth, antialiasWidth, trailDistance);
    if (alpha <= 0.0) {
        return terminal;
    }

    vec2 halfCurrentSize = currentSize * 0.5;
    vec2 currentCenter = currentPosition + vec2(halfCurrentSize.x, -halfCurrentSize.y);
    float currentDistance = rectangleDistance(normalizedCoord, currentCenter, halfCurrentSize);
    float gradientFactor = (normalizedCoord.y + 1.0) * 0.5;
    vec3 trailColor = gradientColor(gradientFactor * sin(iTime));
    float gray = dot(trailColor, vec3(0.299, 0.587, 0.114));
    trailColor = clamp(mix(vec3(gray), trailColor, 1.45), 0.0, 1.0);

    vec4 result = terminal;
    result.rgb = mix(result.rgb, trailColor, alpha * 0.82);
    result.rgb = mix(result.rgb, terminal.rgb, step(currentDistance, 0.0));
    return result;
}

vec4 applyShapeEffect(vec4 terminal, vec2 fragCoord, float elapsed) {
    if (iCursorVisible == 0) {
        return terminal;
    }

    float fullCursorWidth = max(iCurrentCursor.z, iPreviousCursor.z);
    float cursorWidthChange = abs(iCurrentCursor.z - iPreviousCursor.z);
    float modeChanged = step(1.0, fullCursorWidth)
        * step(fullCursorWidth * 0.5, cursorWidthChange);
    float flash = 0.0;
    if (modeChanged > 0.0 && elapsed < CURRENT_FLASH_DURATION) {
        float flashProgress = elapsed / CURRENT_FLASH_DURATION;
        flash = pow(1.0 - flashProgress, 3.0);
    }
    float glowRadius = BASE_GLOW_RADIUS + CURRENT_FLASH_RADIUS_BOOST * flash;
    float glowStrength = BASE_GLOW_STRENGTH
        + CURRENT_FLASH_STRENGTH_BOOST * flash;
    float currentDistance = rectangleDistance(
        fragCoord,
        cursorCenter(iCurrentCursor),
        iCurrentCursor.zw * 0.5
    );
    float currentHalo = exp(-abs(currentDistance) / glowRadius) * glowStrength;
    float echo = 0.0;
    if (modeChanged > 0.0 && elapsed < SHAPE_ECHO_DURATION) {
        float echoProgress = elapsed / SHAPE_ECHO_DURATION;
        float echoFade = 1.0 - smoothstep(0.0, 1.0, echoProgress);
        float previousDistance = rectangleDistance(
            fragCoord,
            cursorCenter(iPreviousCursor),
            iPreviousCursor.zw * 0.5
        );
        echo = exp(-abs(previousDistance) / SHAPE_ECHO_RADIUS)
            * echoFade
            * SHAPE_ECHO_STRENGTH;
    }
    float light = clamp(currentHalo + echo, 0.0, 1.0);
    terminal.rgb = mix(terminal.rgb, iCurrentCursorColor.rgb, light);
    return terminal;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec4 terminal = texture(iChannel0, fragCoord / iResolution.xy);
    fragColor = terminal;

    float elapsed = max(iTime - iTimeCursorChange, 0.0);
    if (outsideEffectBounds(fragCoord, elapsed)) {
        return;
    }

    vec4 composed = applyTrail(terminal, fragCoord, elapsed);
    fragColor = applyShapeEffect(composed, fragCoord, elapsed);
}
