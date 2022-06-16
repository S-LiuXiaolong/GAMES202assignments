#ifdef GL_ES
precision mediump float;
#endif

// Phong related variables
uniform sampler2D uSampler;
uniform vec3 uKd;
uniform vec3 uKs;
uniform vec3 uLightPos;
uniform vec3 uCameraPos;
uniform vec3 uLightIntensity;

varying highp vec2 vTextureCoord;
varying highp vec3 vFragPos;
varying highp vec3 vNormal;

// Shadow map related variables
#define NUM_SAMPLES 20
#define BLOCKER_SEARCH_NUM_SAMPLES NUM_SAMPLES
#define PCF_NUM_SAMPLES NUM_SAMPLES
#define NUM_RINGS 10

#define EPS 1e-3
#define PI 3.141592653589793
#define PI2 6.283185307179586

uniform sampler2D uShadowMap;

varying vec4 vPositionFromLight; // 转换到light space的坐标
// 表示从一维随机变量 x 产生一个 [-1,1] 范围内的随机变量
highp float rand_1to1(highp float x ) { 
  // -1 -1
  return fract(sin(x)*10000.0); // fract(x) = x - floor(x)
}
// 表示从二维随机变量 uv 产生一个 [0,1] 范围的随机变量
highp float rand_2to1(vec2 uv ) { 
  // 0 - 1
	const highp float a = 12.9898, b = 78.233, c = 43758.5453;
	highp float dt = dot( uv.xy, vec2( a,b ) ), sn = mod( dt, PI );
	return fract(sin(sn) * c);
}
// https://stackoverflow.com/questions/19277010/bit-shift-and-bitwise-operations-to-encode-rgb-values
// 此处将一个rgba深度值编码成为一个无二义性的float值
float unpack(vec4 rgbaDepth) {
    const vec4 bitShift = vec4(1.0, 1.0/256.0, 1.0/(256.0*256.0), 1.0/(256.0*256.0*256.0));
    return dot(rgbaDepth, bitShift);
}

vec2 poissonDisk[NUM_SAMPLES];
// 泊松分布采样
// https://electronicmeteor.wordpress.com/2013/02/05/poisson-disc-shadow-sampling-ridiculously-easy-and-good-looking-too/
// https://docs.nvidia.com/gameworks/content/gameworkslibrary/graphicssamples/opengl_samples/softshadowssample.htm
// 大概（？）是用来实现PCF的
void poissonDiskSamples( const in vec2 randomSeed ) {

  float ANGLE_STEP = PI2 * float( NUM_RINGS ) / float( NUM_SAMPLES );
  float INV_NUM_SAMPLES = 1.0 / float( NUM_SAMPLES );

  float angle = rand_2to1( randomSeed ) * PI2;
  float radius = INV_NUM_SAMPLES;
  float radiusStep = radius;

  for( int i = 0; i < NUM_SAMPLES; i ++ ) {
    poissonDisk[i] = vec2( cos( angle ), sin( angle ) ) * pow( radius, 0.75 );
    radius += radiusStep;
    angle += ANGLE_STEP;
  }
}
// 均匀分布采样
void uniformDiskSamples( const in vec2 randomSeed ) {

  float randNum = rand_2to1(randomSeed);
  float sampleX = rand_1to1( randNum ) ;
  float sampleY = rand_1to1( sampleX ) ;

  float angle = sampleX * PI2;
  float radius = sqrt(sampleY);

  for( int i = 0; i < NUM_SAMPLES; i ++ ) {
    poissonDisk[i] = vec2( radius * cos(angle) , radius * sin(angle)  );

    sampleX = rand_1to1( sampleY ) ;
    sampleY = rand_1to1( sampleX ) ;

    angle = sampleX * PI2;
    radius = sqrt(sampleY);
  }
}

float bias() {
  vec3 lightDir = normalize(uLightPos);
  vec3 normal = normalize(vNormal);
  return max(0.005 * (1.0 - dot(normal, lightDir)), 0.005);
}

float useShadowMap(sampler2D shadowMap, vec4 shadowCoord){
  // texture2D: https://thebookofshaders.com/glossary/?search=texture2D
  // 以及 https://learnopengl-cn.github.io/01%20Getting%20started/06%20Textures/
  float bias = bias();
  vec4 depthpack = texture2D(shadowMap,shadowCoord.xy);
  float depthUnpack =unpack(depthpack);
  // 检查当前片段是否在阴影中
  if(depthUnpack > shadowCoord.z - bias)
      return 1.0;
  return 0.0;
}
// https://developer.nvidia.com/gpugems/gpugems/part-ii-lighting-and-shadows/chapter-11-shadow-map-antialiasing
// 随机分布的范围是-1到1，直接在某个像素点计算的话直接飞出uv坐标外了，需要乘一个单位偏移，根据shadowMap的像素来，
// 比如长宽均为2048像素的可以设置一个unit offset=1/2048 他就会在某个像素的周围，按照filter size为半径找随机采样点
float PCF(sampler2D shadowMap, vec4 coords) {
  float bias = bias();
  float shadow = 0.0;
  float currentDepth = coords.z;
  //vec2 filterSize = 1.0 / textureSize(shadowMap, 0);
  float filterSize=  1.0 / 2048.0 * 10.0; // 取10，则在10个像素的范围内寻找采样点
  uniformDiskSamples(coords.xy);
  for(int i = 0; i < PCF_NUM_SAMPLES; ++i)
  {
    vec4 depthpack = texture2D(shadowMap, coords.xy + poissonDisk[i]*filterSize); // 对纹理坐标进行偏移，确保每个新样本，来自不同的深度值
    //float depthUnpack =unpack(vec4(depthpack.xyz,1.0));
    float depthUnpack = unpack(depthpack);
    shadow += (currentDepth - bias > depthUnpack ? 0.0 : 1.0);
  }
  shadow /= float(PCF_NUM_SAMPLES);
  return shadow;
}

float findBlocker( sampler2D shadowMap,  vec2 uv, float zReceiver ) {
	return 1.0;
}

float PCSS(sampler2D shadowMap, vec4 coords){

  // STEP 1: avgblocker depth

  // STEP 2: penumbra size

  // STEP 3: filtering
  
  return 1.0;

}

vec3 blinnPhong() {
  vec3 color = texture2D(uSampler, vTextureCoord).rgb;
  color = pow(color, vec3(2.2));

  vec3 ambient = 0.05 * color;

  vec3 lightDir = normalize(uLightPos);
  vec3 normal = normalize(vNormal);
  float diff = max(dot(lightDir, normal), 0.0);
  vec3 light_atten_coff =
      uLightIntensity / pow(length(uLightPos - vFragPos), 2.0);
  vec3 diffuse = diff * light_atten_coff * color;

  vec3 viewDir = normalize(uCameraPos - vFragPos);
  vec3 halfDir = normalize((lightDir + viewDir));
  float spec = pow(max(dot(halfDir, normal), 0.0), 32.0);
  vec3 specular = uKs * light_atten_coff * spec;

  vec3 radiance = (ambient + diffuse + specular);
  vec3 phongColor = pow(radiance, vec3(1.0 / 2.2));
  return phongColor;
}
// glsl 调试：https://stackoverflow.com/questions/2508818/how-to-debug-a-glsl-shader
void main(void) {

  float visibility;
  // perform perspective divide 执行透视划分
  vec3 projCoords = vPositionFromLight.xyz / vPositionFromLight.w;
  // transform to [0,1] range 变换到[0,1]的范围
  vec3 shadowCoord = projCoords * 0.5 + 0.5;
  // visibility = useShadowMap(uShadowMap, vec4(shadowCoord, 1.0));
  visibility = PCF(uShadowMap, vec4(shadowCoord, 1.0));
  //visibility = PCSS(uShadowMap, vec4(shadowCoord, 1.0));
  
  vec3 phongColor = blinnPhong();

  gl_FragColor = vec4(phongColor * visibility, 1.0);
  // gl_FragColor = vec4(phongColor, 1.0);
  // gl_FragColor = vPositionFromLight;
  // gl_FragColor = vec4(shadowCoord, 1);
  // gl_FragColor = vec4(1,0,0,1); //error
}