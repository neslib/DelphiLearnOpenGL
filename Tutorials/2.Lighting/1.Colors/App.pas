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
  TColorsApp = class(TApplication)
  private
    FCamera: ICamera;
    FLightingShader: IShader;
    FLampShader: IShader;
    FLightingVAO: IVertexArray;
    FLampVAO: IVertexArray;
    FUniformObjectColor: GLint;
    FUniformLightColor: GLint;
    FUniformLightingModel: GLint;
    FUniformLightingView: GLint;
    FUniformLightingProjection: GLint;
    FUniformLampModel: GLint;
    FUniformLampView: GLint;
    FUniformLampProjection: GLint;
    FLastX: Single;
    FLastY: Single;
    FMouseDown: Boolean;
    FKeyW: Boolean;
    FKeyA: Boolean;
    FKeyS: Boolean;
    FKeyD: Boolean;
  private
    procedure HandleInput(const ADeltaTimeSec: Single);
  public
    procedure Initialize; override;
    procedure Update(const ADeltaTimeSec, ATotalTimeSec: Double); override;
    procedure Shutdown; override;
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
  { Each vertex consists of a 3-element position.
    Each group of 4 vertices defines a side of a cube. }
  VERTICES: array [0..71] of Single = (
    // Positions
    -0.5, -0.5, -0.5,
     0.5, -0.5, -0.5,
     0.5,  0.5, -0.5,
    -0.5,  0.5, -0.5,

    -0.5, -0.5,  0.5,
     0.5, -0.5,  0.5,
     0.5,  0.5,  0.5,
    -0.5,  0.5,  0.5,

    -0.5,  0.5,  0.5,
    -0.5,  0.5, -0.5,
    -0.5, -0.5, -0.5,
    -0.5, -0.5,  0.5,

     0.5,  0.5,  0.5,
     0.5,  0.5, -0.5,
     0.5, -0.5, -0.5,
     0.5, -0.5,  0.5,

    -0.5, -0.5, -0.5,
     0.5, -0.5, -0.5,
     0.5, -0.5,  0.5,
    -0.5, -0.5,  0.5,

    -0.5,  0.5, -0.5,
     0.5,  0.5, -0.5,
     0.5,  0.5,  0.5,
    -0.5,  0.5,  0.5);

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
  LIGHT_POS: TVector3 = (X: 1.2; Y: 1.0; Z: 2.0);

{ TColorsApp }

procedure TColorsApp.HandleInput(const ADeltaTimeSec: Single);
begin
  if (FKeyW) then
    FCamera.ProcessKeyboard(TCameraMovement.Forward, ADeltaTimeSec);

  if (FKeyS) then
    FCamera.ProcessKeyboard(TCameraMovement.Backward, ADeltaTimeSec);

  if (FKeyA) then
    FCamera.ProcessKeyboard(TCameraMovement.Left, ADeltaTimeSec);

  if (FKeyD) then
    FCamera.ProcessKeyboard(TCameraMovement.Right, ADeltaTimeSec);
end;

procedure TColorsApp.Initialize;
var
  VertexLayout: TVertexLayout;
begin
  { Initialize the asset manager }
  TAssets.Initialize;

  { Enable depth testing }
  glEnable(GL_DEPTH_TEST);

  { Create camera }
  FCamera := TCamera.Create(Vector3(0, 0, 3));

  { Build and compile our shader programs }
  FLightingShader := TShader.Create('shaders/colors.vs', 'shaders/colors.fs');
  FUniformObjectColor := FLightingShader.GetUniformLocation('objectColor');
  FUniformLightColor := FLightingShader.GetUniformLocation('lightColor');
  FUniformLightingModel := FLightingShader.GetUniformLocation('model');
  FUniformLightingView := FLightingShader.GetUniformLocation('view');
  FUniformLightingProjection := FLightingShader.GetUniformLocation('projection');

  FLampShader := TShader.Create('shaders/lamp.vs', 'shaders/lamp.fs');
  FUniformLampModel := FLampShader.GetUniformLocation('model');
  FUniformLampView := FLampShader.GetUniformLocation('view');
  FUniformLampProjection := FLampShader.GetUniformLocation('projection');

  { Define layout of the attributes in the shader program.
    Both shaders have the same attributes, so just pick one to define the
    vertex layout. }
  VertexLayout.Start(FLightingShader)
    .Add('position', 3);

  { Create the vertex arrays.
    In this tutorial, both the lighting and lamp VAO's use the same vertex data,
    so we could actually just create one VAO. However, in upcoming tutorials,
    their data will be different. }
  FLightingVAO := TVertexArray.Create(VertexLayout,
    VERTICES, SizeOf(VERTICES), INDICES);
  FLampVAO := TVertexArray.Create(VertexLayout,
    VERTICES, SizeOf(VERTICES), INDICES);
end;

procedure TColorsApp.KeyDown(const AKey: Integer; const AShift: TShiftState);
begin
  { Terminate app when Esc key is pressed }
  if (AKey = vkEscape) then
    Terminate;

  if (AKey = vkW) or (AKey = vkUp) then
    FKeyW := True;

  if (AKey = vkA) or (AKey = vkLeft) then
    FKeyA := True;

  if (AKey = vkS) or (AKey = vkDown) then
    FKeyS := True;

  if (AKey = vkD) or (AKey = vkRight) then
    FKeyD := True;
end;

procedure TColorsApp.KeyUp(const AKey: Integer; const AShift: TShiftState);
begin
  if (AKey = vkW) or (AKey = vkUp) then
    FKeyW := False;

  if (AKey = vkA) or (AKey = vkLeft) then
    FKeyA := False;

  if (AKey = vkS) or (AKey = vkDown) then
    FKeyS := False;

  if (AKey = vkD) or (AKey = vkRight) then
    FKeyD := False;
end;

procedure TColorsApp.MouseDown(const AButton: TMouseButton;
  const AShift: TShiftState; const AX, AY: Single);
begin
  FLastX := AX;
  FLastY := AY;
  FMouseDown := True;
end;

procedure TColorsApp.MouseMove(const AShift: TShiftState; const AX, AY: Single);
var
  XOffset, YOffset: Single;
begin
  if (FMouseDown) then
  begin
    XOffset := AX - FLastX;
    YOffset := FLastY - AY; { Reversed since y-coordinates go from bottom to left }

    FLastX := AX;
    FLastY := AY;

    FCamera.ProcessMouseMovement(XOffset, YOffset);
  end;
end;

procedure TColorsApp.MouseUp(const AButton: TMouseButton;
  const AShift: TShiftState; const AX, AY: Single);
begin
  FMouseDown := False;
end;

procedure TColorsApp.MouseWheel(const AShift: TShiftState;
  const AWheelDelta: Integer);
begin
  FCamera.ProcessMouseScroll(AWheelDelta);
end;

procedure TColorsApp.Shutdown;
begin
  { Nothing to do }
end;

procedure TColorsApp.Update(const ADeltaTimeSec, ATotalTimeSec: Double);
var
  Model, View, Projection, Translate, Scale: TMatrix4;
begin
  HandleInput(ADeltaTimeSec);

  { Define the viewport dimensions }
  glViewport(0, 0, Width, Height);

  { Clear the color and depth buffer }
  glClearColor(0.1, 0.1, 0.1, 1.0);
  glClear(GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT);

  { Use corresponding shader when setting uniforms/drawing objects }
  FLightingShader.Use;
  glUniform3f(FUniformObjectColor, 1.0, 0.5, 0.31);
  glUniform3f(FUniformLightColor, 1.0, 0.5, 1.0);

  { Create camera transformation }
  View := FCamera.GetViewMatrix;
  Projection.InitPerspectiveFovRH(Radians(FCamera.Zoom), Width / Height, 0.1, 100.0);

  { Pass matrices to shader }
  glUniformMatrix4fv(FUniformLightingView, 1, GL_FALSE, @View);
  glUniformMatrix4fv(FUniformLightingProjection, 1, GL_FALSE, @Projection);

  { Draw the container }
  Model.Init;
  glUniformMatrix4fv(FUniformLightingModel, 1, GL_FALSE, @Model);
  FLightingVAO.Render;

  { Also draw the lamp object }
  FLampShader.Use;
  glUniformMatrix4fv(FUniformLampView, 1, GL_FALSE, @View);
  glUniformMatrix4fv(FUniformLampProjection, 1, GL_FALSE, @Projection);

  Translate.InitTranslation(LIGHT_POS);
  Scale.InitScaling(0.2); { Make it a smaller cube }
  Model := Scale * Translate;
  glUniformMatrix4fv(FUniformLampModel, 1, GL_FALSE, @Model);
  FLampVAO.Render;
end;

end.
