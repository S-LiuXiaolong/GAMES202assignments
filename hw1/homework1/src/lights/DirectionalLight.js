class DirectionalLight {

    constructor(lightIntensity, lightColor, lightPos, focalPoint, lightUp, hasShadowMap, gl) {
        this.mesh = Mesh.cube(setTransform(0, 0, 0, 0.2, 0.2, 0.2, 0));
        this.mat = new EmissiveMaterial(lightIntensity, lightColor);
        this.lightPos = lightPos;
        this.focalPoint = focalPoint;
        this.lightUp = lightUp

        this.hasShadowMap = hasShadowMap;
        this.fbo = new FBO(gl);
        if (!this.fbo) {
            console.log("无法设置帧缓冲区对象");
            return;
        }
    }

    CalcLightMVP(translate, scale) {
        let lightMVP = mat4.create();
        let modelMatrix = mat4.create();
        let viewMatrix = mat4.create();
        let projectionMatrix = mat4.create();
        console.log("lightpos:", this.lightPos);
        console.log("focalPoint:", this.focalPoint);
        console.log("lightup:", this.lightUp);
        // TODO：为什么，特么这里的传入的translate和scale到底是啥
        // Model transform
        console.log("translate:", translate);
        console.log("scale:", scale);
        mat4.translate(modelMatrix, modelMatrix, translate); // 平移
        console.log("tr_modelMatrix:", modelMatrix);
        mat4.scale(modelMatrix, modelMatrix, scale); // 缩放
        console.log("sc_modelMatrix:", modelMatrix);
        // View transform
        // 见 https://glmatrix.net/docs/module-mat4.html 的lookAt(out, eye, center, up)
        mat4.lookAt(viewMatrix, this.lightPos, this.focalPoint, this.lightUp);
        // Projection transform
        mat4.ortho(projectionMatrix, -120.0, 120.0, -120.0, 120.0, 0, 500);

        mat4.multiply(lightMVP, projectionMatrix, viewMatrix);
        mat4.multiply(lightMVP, lightMVP, modelMatrix);

        return lightMVP;
    }
}
