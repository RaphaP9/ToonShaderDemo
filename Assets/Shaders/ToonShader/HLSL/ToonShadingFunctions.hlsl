#pragma multi_compile _ _MAIN_LIGHT_SHADOWS
#pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
#pragma multi_compile _ _MAIN_LIGHT_SHADOWS_SCREEN

#pragma multi_compile _ _ADDITIONAL_LIGHTS
#pragma multi_compile _ _ADDITIONAL_LIGHT_SHADOWS

#ifndef CEL_SHADING_FUNCTIONS
#define CEL_SHADING_FUNCTIONS

#ifndef SHADERGRAPH_PREVIEW
struct SurfaceVariables
{
    float3 normal;
    float3 view;
    float diffuseLightingOffset;
    float powerShift;
    float specularThreshold;
    float specularIntensity;
    float rimThreshold;
    float rimIntensity;
    float rimPower;
    float rimCurveFactor;
};

float CalculateSpecular(float3 lightDirection, float3 viewDirection, float3 surfaceNormal, float diffuse, float attenuation, float threshold, float intensity)
{
    if (intensity <= 0)
        return 0;
    if (threshold >= 1)
        return 0;
    
    float3 halfVector = SafeNormalize(lightDirection + viewDirection);
    float primitiveSpecular = saturate(dot(surfaceNormal, halfVector));
    
    float specular = step(threshold, primitiveSpecular) * intensity; 
    
    specular *= (diffuse > 0); 
    
    return specular;
}

float CalculateRim(float3 viewDirection, float3 surfaceNormal, float diffuse, float attenuation, float threshold, float intensity, float rimPower, float rimCurveFactor)
{
    if (intensity <= 0)
        return 0;
    if (threshold >= 1)
        return 0;
    
    float primitiveRim = 1 - saturate(dot(viewDirection, surfaceNormal));     
    primitiveRim = pow(primitiveRim, rimPower);
    primitiveRim *= lerp(1.0, diffuse, rimCurveFactor); 
    
    float rim = step(threshold, primitiveRim) * intensity; 

    rim *= (diffuse > 0);
    
    return rim;
}

float3 CalculateCelShading(Light l, SurfaceVariables s, float diffuseIntensity, float minimumLight)
{
    float diffuse = saturate(dot(s.normal, l.direction) + s.diffuseLightingOffset);
    float attenuation = l.distanceAttenuation * l.shadowAttenuation;  
    
    attenuation = saturate(attenuation); 
    diffuse *= attenuation;  
    
    float lighting = step(0.0001, diffuse); 
    lighting = clamp(lighting, minimumLight, 1.0);
    lighting *= diffuseIntensity;

    float specular = CalculateSpecular(l.direction, s.view, s.normal, diffuse, attenuation, s.specularThreshold, s.specularIntensity);
    float rim = CalculateRim(s.view, s.normal, diffuse, attenuation, s.rimThreshold, s.rimIntensity, s.rimPower, s.rimCurveFactor);
    
    float addOn = max(specular, rim);
    lighting += addOn; //Add to the bandedLighting
    
    lighting = pow(abs(lighting), s.powerShift); 
    
    return l.color * lighting;
}
#endif

void LightingCelShaded_float(
    float3 Position,
    float3 Normal,
    float3 View,
    float DiffuseMainLightIntensity,
    float DiffuseAdditionalLightsIntensity,
    float DiffuseLightingOffset,
    float MinimumDiffuseMainLight,
    float PowerShift,
    float SpecularThreshold,
    float SpecularIntensity,
    float RimThreshold,
    float RimIntensity,
    float RimPower,
    float RimCurveFactor,
    out float3 Color
)
{
#if defined(SHADERGRAPH_PREVIEW)
    Color = float3(0.5f,0.5f,0.5f);
#else
    SurfaceVariables s;
    s.normal = normalize(Normal);
    s.view = SafeNormalize(View);
    s.diffuseLightingOffset = DiffuseLightingOffset;
    s.powerShift = PowerShift;
    s.specularThreshold = SpecularThreshold;
    s.specularIntensity = SpecularIntensity;
    s.rimThreshold = RimThreshold;
    s.rimIntensity = RimIntensity;
    s.rimPower = RimPower;
    s.rimCurveFactor = RimCurveFactor;
    
    Color = float3(0.0f, 0.0f, 0.0f);
    
    #if defined (_USEMAINLIGHT)
        Light mainLight;
        
        #if defined (_USEMAINLIGHTSHADOWS)
            #if defined(_MAIN_LIGHT_SHADOWS_SCREEN)
                float4 shadowCoord = ComputeScreenPos(TransformWorldToHClip(Position));
            #else 
                float4 shadowCoord = TransformWorldToShadowCoord(Position);
            #endif
            
            mainLight = GetMainLight(shadowCoord);
        #else
            mainLight = GetMainLight();
        #endif
        
        Color += CalculateCelShading(mainLight, s, DiffuseMainLightIntensity, MinimumDiffuseMainLight);
    
#endif
    
    #if defined(_USEADDITIONALLIGHTS) && defined(_ADDITIONAL_LIGHTS)

    int pixelLightCount = GetAdditionalLightsCount();

    for (int i = 0; i < pixelLightCount; i++)
    {
        #if defined(_USEADDITIONALLIGHTSSHADOWS) && defined(_ADDITIONAL_LIGHT_SHADOWS)
            Light additionalLight = GetAdditionalLight(i, Position, 1);
        #else
            Light additionalLight = GetAdditionalLight(i, Position);
        #endif

        
        Color += CalculateCelShading(additionalLight, s, DiffuseAdditionalLightsIntensity, 0);
    }

#endif
#endif
}
#endif