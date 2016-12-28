unit App;

{$INCLUDE 'Sample.inc'}

interface

uses
  System.Classes,
  System.UITypes,
  System.SysUtils,
  {$INCLUDE 'OpenGL.inc'}
  Sample.Classes,
  Sample.App;

type
  TLightCastersApp = class(TApplication)
  private
    FCamera: ICamera;
    FLightingShader: IShader;
    FContainerVAO: IVertexArray;
    FDiffuseMap: GLuint;
    FSpecularMap: GLuint;
    FUniformViewPos: GLint;
    FUniformLightPosition: GLint;
    FUniformLightDirection: GLint;
    FUniformLightCutOff: GLint;
    FUniformLightOuterCutOff: GLint;
    FUniformLightConstant: GLint;
    FUniformLightLinear: GLint;
    FUniformLightQuadratic: GLint;
    FUniformLightAmbient: GLint;
    FUniformLightDiffuse: GLint;
    FUniformLightSpecular: GLint;
    FUniformMaterialShininess: GLint;
    FUniformContainerModel: GLint;
    FUniformContainerView: GLint;
    FUniformContainerProjection: GLint;
    FUniformContainerNormalMatrix: GLint;
  public
    procedure Initialize; override;
    procedure Update(const ADeltaTimeSec, ATotalTimeSec: Double); override;
    procedure Shutdown; override;
    procedure Resize(const AWidth, AHeight: Integer); override;
  public
    procedure KeyDown(const AKey: Integer; const AShift: TShiftState); override;
    procedure KeyUp(const AKey: Integer; const AShift: TShiftState); override;
    procedure MouseDown(const AButton: TMouseButton; const AShift: TShiftState;
      const AX, AY: Single); override;
    procedure MouseMove(const AShift: TShiftState; const AX, AY: Single); override;
    procedure MouseUp(const AButton: TMouseButton; const AShift: TShiftState;
      const AX, AY: Single); override;
    procedure MouseWheel(const AShift: TShiftState; const AWheelDelta: Integer); override;
  end;

implementation

uses
  Neslib.Stb.Image,
  Neslib.FastMath;

const
  { Each container vertex consists of a 3-element position and a 3-element
    normal and a 2-element texture coordinate.
    Each group of 4 vertices defines a side of a cube. }
  CONTAINER_VERTICES: array [0..191] of Single = (
    // Positions      // Normals         // Texture Coords
    -0.5, -0.5, -0.5,  0.0,  0.0, -1.0,  0.0, 0.0,
     0.5, -0.5, -0.5,  0.0,  0.0, -1.0,  1.0, 0.0,
     0.5,  0.5, -0.5,  0.0,  0.0, -1.0,  1.0, 1.0,
    -0.5,  0.5, -0.5,  0.0,  0.0, -1.0,  0.0, 1.0,

    -0.5, -0.5,  0.5,  0.0,  0.0,  1.0,  0.0, 0.0,
     0.5, -0.5,  0.5,  0.0,  0.0,  1.0,  1.0, 0.0,
     0.5,  0.5,  0.5,  0.0,  0.0,  1.0,  1.0, 1.0,
    -0.5,  0.5,  0.5,  0.0,  0.0,  1.0,  0.0, 1.0,

    -0.5,  0.5,  0.5, -1.0,  0.0,  0.0,  1.0, 0.0,
    -0.5,  0.5, -0.5, -1.0,  0.0,  0.0,  1.0, 1.0,
    -0.5, -0.5, -0.5, -1.0,  0.0,  0.0,  0.0, 1.0,
    -0.5, -0.5,  0.5, -1.0,  0.0,  0.0,  0.0, 0.0,

     0.5,  0.5,  0.5,  1.0,  0.0,  0.0,  1.0, 0.0,
     0.5,  0.5, -0.5,  1.0,  0.0,  0.0,  1.0, 1.0,
     0.5, -0.5, -0.5,  1.0,  0.0,  0.0,  0.0, 1.0,
     0.5, -0.5,  0.5,  1.0,  0.0,  0.0,  0.0, 0.0,

    -0.5, -0.5, -0.5,  0.0, -1.0,  0.0,  0.0, 1.0,
     0.5, -0.5, -0.5,  0.0, -1.0,  0.0,  1.0, 1.0,
     0.5, -0.5,  0.5,  0.0, -1.0,  0.0,  1.0, 0.0,
    -0.5, -0.5,  0.5,  0.0, -1.0,  0.0,  0.0, 0.0,

    -0.5,  0.5, -0.5,  0.0,  1.0,  0.0,  0.0, 1.0,
     0.5,  0.5, -0.5,  0.0,  1.0,  0.0,  1.0, 1.0,
     0.5,  0.5,  0.5,  0.0,  1.0,  0.0,  1.0, 0.0,
    -0.5,  0.5,  0.5,  0.0,  1.0,  0.0,  0.0, 0.0);

const
  { The indices define 2 triangles per cube face, 6 faces total }
  INDICES: array [0..35] of UInt16 = (
     0,  1,  2,   2,  3,  0,
     4,  5,  6,   6,  7,  4,
     8,  9, 10,  10, 11,  8,
    12, 13, 14,  14, 15, 12,
    16, 17, 18,  18, 19, 16,
    20, 21, 22,  22, 23, 20);

const
  // Positions all containers
  CUBE_POSITIONS: array [0..9] of TVector3 = (
    (X:  0.0; Y:  0.0; Z:   0.0),
    (X:  2.0; Y:  5.0; Z: -15.0),
    (X: -1.5; Y: -2.2; Z:  -2.5),
    (X: -3.8; Y: -2.0; Z: -12.3),
    (X:  2.4; Y: -0.4; Z:  -3.5),
    (X: -1.7; Y:  3.0; Z:  -7.5),
    (X:  1.3; Y: -2.0; Z:  -2.5),
    (X:  1.5; Y:  2.0; Z:  -2.5),
    (X:  1.5; Y:  0.2; Z:  -1.5),
    (X: -1.3; Y:  1.0; Z:  -1.5));

{ TLightCastersApp }

procedure TLightCastersApp.Initialize;
var
  VertexLayout: TVertexLayout;
  Data: TBytes;
  Image: Pointer;
  ImageWidth, ImageHeight, ImageComponents: Integer;
begin
  { Initialize the asset manager }
  TAssets.Initialize;

  { Enable depth testing }
  glEnable(GL_DEPTH_TEST);

  { Create camera }
  FCamera := TCamera.Create(Width, Height, Vector3(0, 0, 3));

  { Build and compile our shader programs }
  FLightingShader := TShader.Create('shaders/light_casters.vs', 'shaders/light_casters.fs');
  FUniformViewPos := FLightingShader.GetUniformLocation('viewPos');
  FUniformLightPosition := FLightingShader.GetUniformLocation('light.position');
  FUniformLightDirection := FLightingShader.GetUniformLocation('light.direction');
  FUniformLightCutOff := FLightingShader.GetUniformLocation('light.cutOff');
  FUniformLightOuterCutOff := FLightingShader.GetUniformLocation('light.outerCutOff');
  FUniformLightConstant := FLightingShader.GetUniformLocation('light.constant');
  FUniformLightLinear := FLightingShader.GetUniformLocation('light.linear');
  FUniformLightQuadratic := FLightingShader.GetUniformLocation('light.quadratic');
  FUniformLightAmbient := FLightingShader.GetUniformLocation('light.ambient');
  FUniformLightDiffuse := FLightingShader.GetUniformLocation('light.diffuse');
  FUniformLightSpecular := FLightingShader.GetUniformLocation('light.specular');
  FUniformMaterialShininess := FLightingShader.GetUniformLocation('material.shininess');
  FUniformContainerModel := FLightingShader.GetUniformLocation('model');
  FUniformContainerView := FLightingShader.GetUniformLocation('view');
  FUniformContainerProjection := FLightingShader.GetUniformLocation('projection');
  FUniformContainerNormalMatrix := FLightingShader.GetUniformLocation('normalMatrix');

  { Define layout of the attributes in the Lighting shader }
  VertexLayout.Start(FLightingShader)
    .Add('position', 3)
    .Add('normal', 3)
    .Add('texCoords', 2);

  { Create the vertex array for the container. }
  FContainerVAO := TVertexArray.Create(VertexLayout,
    CONTAINER_VERTICES, SizeOf(CONTAINER_VERTICES), INDICES);

  { Load textures }

  { Diffuse Map
    =========== }
  glGenTextures(1, @FDiffuseMap);
  glBindTexture(GL_TEXTURE_2D, FDiffuseMap);

  { Set our texture parameters }
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);

  { Set texture filtering }
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);

  { Load, create texture and generate mipmaps }
  Data := TAssets.Load('textures/container2.png');
  Assert(Assigned(Data));
  Image := stbi_load_from_memory(Data, Length(Data), ImageWidth, ImageHeight, ImageComponents, 3);
  Assert(Assigned(Image));
  glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB, ImageWidth, ImageHeight, 0, GL_RGB, GL_UNSIGNED_BYTE, Image);
  stbi_image_free(Image);
  glBindTexture(GL_TEXTURE_2D, 0);
  glErrorCheck;

  { Specular Map
    ============ }
  glGenTextures(1, @FSpecularMap);
  glBindTexture(GL_TEXTURE_2D, FSpecularMap);
  { All upcoming GL_TEXTURE_2D operations now have effect on our texture object }

  { Set our texture parameters }
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);

  { Set texture filtering }
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);

  { Load, create texture and generate mipmaps }
  Data := TAssets.Load('textures/container2_specular.png');
  Assert(Assigned(Data));
  Image := stbi_load_from_memory(Data, Length(Data), ImageWidth, ImageHeight, ImageComponents, 3);
  Assert(Assigned(Image));
  glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB, ImageWidth, ImageHeight, 0, GL_RGB, GL_UNSIGNED_BYTE, Image);
  stbi_image_free(Image);
  glBindTexture(GL_TEXTURE_2D, 0);
  glErrorCheck;

  { Set texture units }
  FLightingShader.Use;
  glUniform1i(FLightingShader.GetUniformLocation('material.diffuse'), 0);
  glUniform1i(FLightingShader.GetUniformLocation('material.specular'), 1);
end;

procedure TLightCastersApp.KeyDown(const AKey: Integer; const AShift: TShiftState);
begin
  if (AKey = vkEscape) then
    { Terminate app when Esc key is pressed }
    Terminate
  else
    FCamera.ProcessKeyDown(AKey);
end;

procedure TLightCastersApp.KeyUp(const AKey: Integer; const AShift: TShiftState);
begin
  FCamera.ProcessKeyUp(AKey);
end;

procedure TLightCastersApp.MouseDown(const AButton: TMouseButton;
  const AShift: TShiftState; const AX, AY: Single);
begin
  FCamera.ProcessMouseDown(AX, AY);
end;

procedure TLightCastersApp.MouseMove(const AShift: TShiftState; const AX, AY: Single);
begin
  FCamera.ProcessMouseMove(AX, AY);
end;

procedure TLightCastersApp.MouseUp(const AButton: TMouseButton;
  const AShift: TShiftState; const AX, AY: Single);
begin
  FCamera.ProcessMouseUp;
end;

procedure TLightCastersApp.MouseWheel(const AShift: TShiftState;
  const AWheelDelta: Integer);
begin
  FCamera.ProcessMouseWheel(AWheelDelta);
end;

procedure TLightCastersApp.Resize(const AWidth, AHeight: Integer);
begin
  inherited;
  if Assigned(FCamera) then
    FCamera.ViewResized(AWidth, AHeight);
end;

procedure TLightCastersApp.Shutdown;
begin
  glDeleteTextures(1, @FDiffuseMap);
  glDeleteTextures(1, @FSpecularMap);
end;

procedure TLightCastersApp.Update(const ADeltaTimeSec, ATotalTimeSec: Double);
var
  Model, View, Projection, Translate, Rotate: TMatrix4;
  NormalMatrix: TMatrix3;
  I: Integer;
begin
  FCamera.HandleInput(ADeltaTimeSec);

  { Define the viewport dimensions }
  glViewport(0, 0, Width, Height);

  { Clear the color and depth buffer }
  glClearColor(0.1, 0.1, 0.1, 1.0);
  glClear(GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT);

  { Use corresponding shader when setting uniforms/drawing objects }
  FLightingShader.Use;
  glUniform3f(FUniformLightPosition, FCamera.Position.X, FCamera.Position.Y, FCamera.Position.Z);
  glUniform3f(FUniformLightDirection, FCamera.Front.X, FCamera.Front.Y, FCamera.Front.Z);
  glUniform1f(FUniformLightCutOff, Cos(Radians(12.5)));
  glUniform1f(FUniformLightOuterCutOff, Cos(Radians(17.5)));
  glUniform3f(FUniformViewPos, FCamera.Position.X, FCamera.Position.Y, FCamera.Position.Z);

  { Set light properties }
  glUniform3f(FUniformLightAmbient,   0.1, 0.1, 0.1);
  { We set the diffuse intensity a bit higher; note that the right lighting
    conditions differ with each lighting method and environment.
    Each environment and lighting type requires some tweaking of these variables
    to get the best out of your environment. }
  glUniform3f(FUniformLightDiffuse,   0.8, 0.8, 0.8);
  glUniform3f(FUniformLightSpecular,  1.0, 1.0, 1.0);
  glUniform1f(FUniformLightConstant,  1.0);
  glUniform1f(FUniformLightLinear,    0.09);
  glUniform1f(FUniformLightQuadratic, 0.032);

  { Set material properties }
  glUniform1f(FUniformMaterialShininess, 32.0);

  { Create camera transformation }
  View := FCamera.GetViewMatrix;
  Projection.InitPerspectiveFovRH(Radians(FCamera.Zoom), Width / Height, 0.1, 100.0);

  { Pass matrices to shader }
  glUniformMatrix4fv(FUniformContainerView, 1, GL_FALSE, @View);
  glUniformMatrix4fv(FUniformContainerProjection, 1, GL_FALSE, @Projection);

  { Bind diffuse map }
  glActiveTexture(GL_TEXTURE0);
  glBindTexture(GL_TEXTURE_2D, FDiffuseMap);

  { Bind specular map }
  glActiveTexture(GL_TEXTURE1);
  glBindTexture(GL_TEXTURE_2D, FSpecularMap);

  { Draw 10 containers with the same VAO and VBO information;
    only their world space coordinates differ }
  FContainerVAO.BeginRender;
  for I := 0 to Length(CUBE_POSITIONS) - 1 do
  begin
    { Create Model matrix }
    Translate.InitTranslation(CUBE_POSITIONS[I]);
    Rotate.InitRotation(Vector3(1.0, 0.3, 0.5), Radians(20.0 * I));
    Model := Rotate * Translate;

    { Calculate Normal matrix }
    NormalMatrix.Init(Model);
    NormalMatrix := NormalMatrix.Inverse.Transpose;

    { Draw the container }
    glUniformMatrix4fv(FUniformContainerModel, 1, GL_FALSE, @Model);
    glUniformMatrix3fv(FUniformContainerNormalMatrix, 1, GL_FALSE, @NormalMatrix);
    FContainerVAO.Render;
  end;
  FContainerVAO.EndRender;
end;

end.
