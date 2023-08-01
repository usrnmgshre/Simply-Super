// For Physics Mod support: https://github.com/haubna/PhysicsMod/blob/main/oceans.glsl

// just some basic consts for the wave function based on afl_ext's shader https://www.shadertoy.com/view/Xdlczl
// the overall shape must stay consistent because it is also computed on the CPU side
// to offset entities (though a custom CPU integration of your shader is possible by
// contacting me on my discord server https://discord.gg/VsNs9xP)

// this is the surface detail from the physics options, ranges from 13 to 48 (yeah I know weird)
uniform int physics_iterationsNormal;
// used to offset the 0 point of wave meshes to keep the wave function consistent even
// though the mesh totally changes
// uniform vec2 physics_waveOffset;
// used for offsetting the local position to fetch the right pixel of the waviness texture
// uniform ivec2 physics_textureOffset;
// time in seconds that can go faster dependent on weather conditions (affected by weather strength
// multiplier in ocean settings
uniform float physics_gameTime;
// global time
uniform float physics_globalTime;
// base value is 13 and gets multiplied by wave height in ocean settings
uniform float physics_oceanHeight;
// basic texture to determine how shallow/far away from the shore the water is
// uniform sampler2D physics_waviness;
// basic scale for the horizontal size of the waves
uniform float physics_oceanWaveHorizontalScale;
// used to offset the model to know the ripple position
uniform vec3 physics_modelOffset;
// used for offsetting the ripple texture
uniform float physics_rippleRange;
// controlling how much foam generates on the ocean
uniform float physics_foamAmount;
// controlling the opacity of the foam
uniform float physics_foamOpacity;
// texture containing the ripples (basic bump map)
uniform sampler2D physics_ripples;
// foam noise
uniform sampler3D physics_foam;
// just the generic minecraft lightmap, you can remove this and use the one supplied by Optifine/Iris
// uniform sampler2D physics_lightmap;

/*
vec2 physics_waveDirection(vec2 position, int iterations){
    float iter = 0.0;
    float frequency = PHYSICS_FREQUENCY;
    float speed = PHYSICS_SPEED;
    float weight = 1.0;
    float waveSum = 0.0;
    float modifiedTime = physics_gameTime * PHYSICS_TIME_MULTIPLICATOR;

    vec2 dx = vec2(0);

    for(int i = 0; i < iterations; i++){
        vec2 direction = vec2(sin(iter), cos(iter));

        float x = dot(direction, position) * frequency + modifiedTime * speed;
        float wave = exp(sin(x) - 1.0);
        float result = wave * cos(x);

        vec2 force = result * weight * direction;
        
        dx += force / pow(weight, PHYSICS_W_DETAIL); 
        position -= force * PHYSICS_DRAG_MULT;
        iter += PHYSICS_ITER_INC;
        waveSum += weight;
        weight *= PHYSICS_WEIGHT;
        frequency *= PHYSICS_FREQUENCY_MULT;
        speed *= PHYSICS_SPEED_MULT;
    }
    
    return vec2(dx / pow(waveSum, 1.0 - PHYSICS_W_DETAIL));
}
*/

vec3 physics_waveNormal(in vec2 position, in vec2 direction, in float factor){
    float oceanHeightFactor = physics_oceanHeight / 13.0;
    float totalFactor = oceanHeightFactor * factor;

    vec3 waveNormal = normalize(vec3(direction.x * totalFactor, PHYSICS_NORMAL_STRENGTH, direction.y * totalFactor));
    
    vec2 eyePosition = position + physics_modelOffset.xz;
    vec2 rippleFetch = (eyePosition + vec2(physics_rippleRange)) / (physics_rippleRange * 2.0);
    vec2 rippleTexelSize = vec2(2.0 / textureSize(physics_ripples, 0).x, 0);

    float left = texture(physics_ripples, rippleFetch - rippleTexelSize.xy).r;
    float right = texture(physics_ripples, rippleFetch + rippleTexelSize.xy).r;
    float top = texture(physics_ripples, rippleFetch - rippleTexelSize.yx).r;
    float bottom = texture(physics_ripples, rippleFetch + rippleTexelSize.yx).r;
    float totalEffect = left + right + top + bottom;
    
    float normalx = left - right;
    float normalz = top - bottom;

    vec3 rippleNormal = normalize(vec3(normalx, 1.0, normalz));

    return normalize(mix(waveNormal, rippleNormal, sqrt(totalEffect)));
}

struct WavePixelData{
    float foam;
    float height;

    vec2 direction;
    vec2 worldPos;

    vec3 normal;
};

WavePixelData physics_wavePixel(in vec2 position, in float factor){
    vec2 wavePos = position;

    float iter = 0.0;
    float frequency = PHYSICS_FREQUENCY;
    float speed = PHYSICS_SPEED;
    float weight = 1.0;
    float height = 0.0;
    float waveSum = 0.0;
    float modifiedTime = physics_gameTime * PHYSICS_TIME_MULTIPLICATOR;

    vec2 dx = vec2(0);
    
    for(int i = 0; i < physics_iterationsNormal; i++){
        vec2 direction = vec2(sin(iter), cos(iter));
        float x = dot(direction, wavePos) * frequency + modifiedTime * speed;
        float wave = exp(sin(x) - 1.0);
        float result = wave * cos(x);
    
        vec2 force = result * weight * direction;
        
        dx += force / pow(weight, PHYSICS_W_DETAIL); 
        wavePos -= force * PHYSICS_DRAG_MULT;
        height += wave * weight;
        iter += PHYSICS_ITER_INC;
        waveSum += weight;
        weight *= PHYSICS_WEIGHT;
        frequency *= PHYSICS_FREQUENCY_MULT;
        speed *= PHYSICS_SPEED_MULT;
    }
    
    WavePixelData data;
    data.direction = -vec2(dx / pow(waveSum, 1.0 - PHYSICS_W_DETAIL));
    data.worldPos = wavePos / physics_oceanWaveHorizontalScale / PHYSICS_XZ_SCALE;
    data.height = height / waveSum * physics_oceanHeight * factor - physics_oceanHeight * factor * 0.5;
    
    data.normal = physics_waveNormal(position, data.direction, factor);

    float waveAmplitude = data.height * squared(squared(max(data.normal.y, 0.0)));

    vec2 waterUV = mix(position, data.worldPos, clamp(factor * 2.0, 0.2, 1.0));

    vec2 s1 = textureLod(physics_foam, vec3(waterUV * 0.26, physics_globalTime / 360.0), 0).rg;
    vec2 s2 = textureLod(physics_foam, vec3(waterUV * 0.02, physics_globalTime / 360.0 + 0.5), 0).rg;
    vec2 s3 = textureLod(physics_foam, vec3(waterUV * 0.1, physics_globalTime / 360.0 + 1.0), 0).rg;

    float waterSurfaceNoise = s1.r * s2.r * s3.r * 2.8 * physics_foamAmount;

    waveAmplitude = saturate(waveAmplitude * 1.2);
    waterSurfaceNoise = (1.0 - waveAmplitude) * waterSurfaceNoise + waveAmplitude * physics_foamAmount;
    
    float worleyNoise = 0.2 + 0.8 * s1.g * (1.0 - s2.g);

    const float waterFoamMinSmooth = 0.45;
    const float waterFoamMaxSmooth = 2.0;

    waterSurfaceNoise = smoothstep(waterFoamMinSmooth, 1.0, waterSurfaceNoise) * worleyNoise;
    
    data.foam = saturate(waterFoamMaxSmooth * waterSurfaceNoise * physics_foamOpacity);
    
    return data;
}

/*
// FRAGMENT STAGE
void main(){
    // access the wave struct data however you want, wave.normal is in world space, wave.foam is the final foam amount
    WavePixelData wave = physics_wavePixel(physics_localPosition, physics_localWaviness);
}
*/