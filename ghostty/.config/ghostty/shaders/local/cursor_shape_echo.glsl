// Static halo, a brief new-shape flash, and an old-shape echo on mode changes.

const float BASE_GLOW_RADIUS = 10.0;
const float BASE_GLOW_STRENGTH = 0.24;
const float CURRENT_FLASH_DURATION = 0.16;
const float CURRENT_FLASH_RADIUS_BOOST = 5.0;
const float CURRENT_FLASH_STRENGTH_BOOST = 0.14;
const float SHAPE_ECHO_DURATION = 0.20;
const float SHAPE_ECHO_RADIUS = 4.0;
const float SHAPE_ECHO_STRENGTH = 0.28;

float rectangleDistance(vec2 point, vec2 center, vec2 halfSize) {
    vec2 delta = abs(point - center) - halfSize;
    return length(max(delta, 0.0)) + min(max(delta.x, delta.y), 0.0);
}

vec2 cursorCenter(vec4 cursor) {
    return cursor.xy + vec2(cursor.z * 0.5, -cursor.w * 0.5);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec4 terminal = texture(iChannel0, fragCoord / iResolution.xy);
    fragColor = terminal;

    if (iCursorVisible == 0) {
        return;
    }

    float fullCursorWidth = max(iCurrentCursor.z, iPreviousCursor.z);
    float cursorWidthChange = abs(iCurrentCursor.z - iPreviousCursor.z);
    float modeChanged = step(1.0, fullCursorWidth)
        * step(fullCursorWidth * 0.5, cursorWidthChange);
    float elapsed = iTime - iTimeCursorChange;

    float flashProgress = clamp(elapsed / CURRENT_FLASH_DURATION, 0.0, 1.0);
    float flash = modeChanged * pow(1.0 - flashProgress, 3.0);
    float currentGlowRadius = BASE_GLOW_RADIUS + CURRENT_FLASH_RADIUS_BOOST * flash;
    float currentGlowStrength = BASE_GLOW_STRENGTH
        + CURRENT_FLASH_STRENGTH_BOOST * flash;
    float currentDistance = rectangleDistance(
        fragCoord,
        cursorCenter(iCurrentCursor),
        iCurrentCursor.zw * 0.5
    );
    float currentHalo = exp(-abs(currentDistance) / currentGlowRadius)
        * currentGlowStrength;

    float echoProgress = clamp(
        elapsed / SHAPE_ECHO_DURATION,
        0.0,
        1.0
    );
    float echoFade = modeChanged * (1.0 - smoothstep(0.0, 1.0, echoProgress));
    float previousDistance = rectangleDistance(
        fragCoord,
        cursorCenter(iPreviousCursor),
        iPreviousCursor.zw * 0.5
    );
    float echo = exp(-abs(previousDistance) / SHAPE_ECHO_RADIUS)
        * echoFade
        * SHAPE_ECHO_STRENGTH;

    vec3 glowColor = iCurrentCursorColor.rgb;
    float light = clamp(currentHalo + echo, 0.0, 1.0);
    vec3 haloed = mix(terminal.rgb, glowColor, light);

    fragColor = vec4(haloed, terminal.a);
}
