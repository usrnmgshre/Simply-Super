/*
================================ /// Super Duper Vanilla v1.3.4 /// ================================

    Developed by Eldeston, presented by FlameRender (TM) Studios.

    Copyright (C) 2023 Eldeston | FlameRender (TM) Studios License


    By downloading this content you have agreed to the license and its terms of use.

================================ /// Super Duper Vanilla v1.3.4 /// ================================
*/

/// Buffer features: SSGI calculation

/// -------------------------------- /// Vertex Shader /// -------------------------------- ///

#ifdef VERTEX
    out vec2 texCoord;

    void main(){
        // Get buffer texture coordinates
        texCoord = gl_MultiTexCoord0.xy;
        gl_Position = ftransform();
    }
#endif

/// -------------------------------- /// Fragment Shader /// -------------------------------- ///

#ifdef FRAGMENT
    in vec2 texCoord;

    uniform float frameTimeCounter;

    uniform mat4 gbufferProjection;
    uniform mat4 gbufferProjectionInverse;

    uniform sampler2D gcolor;
    uniform sampler2D colortex1;
    uniform sampler2D colortex2;
    uniform sampler2D colortex5;

    uniform sampler2D depthtex0;

    #include "/lib/utility/convertViewSpace.glsl"
    #include "/lib/utility/convertScreenSpace.glsl"
    #include "/lib/utility/noiseFunctions.glsl"

    #include "/lib/rayTracing/rayTracer.glsl"

    void main(){
        // Screen texel coordinates
        ivec2 screenTexelCoord = ivec2(gl_FragCoord.xy);
        // Get screen pos
        vec3 screenPos = vec3(texCoord, texelFetch(depthtex0, screenTexelCoord, 0).x);
        // Get view pos
        vec3 viewPos = toView(screenPos);

        // Create variable for holding SSGI color
        vec3 SSGIcol;

        #if ANTI_ALIASING >= 2
            vec3 dither = toRandPerFrame(getRand3(screenTexelCoord & 255), frameTimeCounter);
        #else
            vec3 dither = getRand3(screenTexelCoord & 255);
        #endif

        vec3 albedo = texelFetch(colortex2, screenTexelCoord, 0).rgb;
        vec3 normal = texelFetch(colortex1, screenTexelCoord, 0).xyz;

        #ifdef SSGI
            vec3 noiseUnitVector = generateUnitVector(dither.xy);

	    	// Get SSGI screen coordinates
	    	vec3 SSGIcoord = rayTraceScene(screenPos, viewPos, generateCosineVector(normal, noiseUnitVector), dither.z, SSGI_STEPS, SSGI_BISTEPS);

	    	// If sky don't do SSGI
	    	#ifdef PREVIOUS_FRAME
	    		if(SSGIcoord.z > 0.5) SSGIcol += albedo * textureLod(colortex5, toPrevScreenPos(SSGIcoord.xy), 0).rgb;
	    	#else
	    		if(SSGIcoord.z > 0.5) SSGIcol += albedo * textureLod(gcolor, SSGIcoord.xy, 0).rgb;
	    	#endif
	    #endif

    /* DRAWBUFFERS:6 */
        gl_FragData[0] = vec4(SSGIcol, 1); // colortex6
    }
#endif
