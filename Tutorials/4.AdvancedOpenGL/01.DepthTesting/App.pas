unit App;

{$INCLUDE 'Sample.inc'}

interface

uses
  System.Classes,
  System.UITypes,
  System.SysUtils,
  {$INCLUDE 'OpenGL.inc'}
  Sample.Classes,
  Sample.Common,
  Sample.App;

type
  TDepthTestingApp = class(TApplication)
  private
    FCamera: ICamera;
    FShader: IShader;
    FCubeVAO: IVertexArray;
    FPlaneVAO: IVertexArray;
    FUniformMVP: TUniformMVP;
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
  Neslib.FastMath;

const
  { Each cube vertex consists of a 3-element position.
    Each group of 4 vertices defines a side of a cube. }
  CUBE_VERTICES: array [0..71] of Single = (
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
  CUBE_INDICES: array [0..35] of UInt16 = (
     0,  1,  2,   2,  3,  0,
     4,  5,  6,   6,  7,  4,
     8,  9, 10,  10, 11,  8,
    12, 13, 14,  14, 15, 12,
    16, 17, 18,  18, 19, 16,
    20, 21, 22,  22, 23, 20);

const
  { Each plane vertex consists of a 3-element position. }
  PLANE_VERTICES: array [0..11] of Single = (
    // Positions
     5.0, -0.5,  5.0,
    -5.0, -0.5,  5.0,
    -5.0, -0.5, -5.0,
     5.0, -0.5, -5.0);

const
  PLANE_INDICES: array [0..5] of UInt16 = (0, 1, 2, 0, 2, 3);

{ TDepthTestingApp }

procedure TDepthTestingApp.Initialize;
var
  VertexLayout: TVertexLayout;
begin
  { Initialize the asset manager }
  TAssets.Initialize;

  { Enable depth testing }
  glEnable(GL_DEPTH_TEST);
  // glDepthFunc(GL_ALWAYS); // Set to always pass the depth test (same effect as glDisable(GL_DEPTH_TEST))

  { Create camera }
  FCamera := TCamera.Create(Width, Height, Vector3(0, 0, 3));

  { Build and compile our shader program }
  FShader := TShader.Create('shaders/depth_testing.vs', 'shaders/depth_testing.fs');
  FUniformMVP.Init(FShader);

  { Define layout of the attributes in the shader }
  VertexLayout.Start(FShader)
    .Add('position', 3);

  { Create the vertex array for the cube. }
  FCubeVAO := TVertexArray.Create(VertexLayout,
    CUBE_VERTICES, SizeOf(CUBE_VERTICES), CUBE_INDICES);

  { Create the vertex array for the plane.
    It uses the same vertex layout as the cube. }
  FPlaneVAO := TVertexArray.Create(VertexLayout,
    PLANE_VERTICES, SizeOf(PLANE_VERTICES), PLANE_INDICES);
end;

procedure TDepthTestingApp.KeyDown(const AKey: Integer; const AShift: TShiftState);
begin
  if (AKey = vkEscape) then
    { Terminate app when Esc key is pressed }
    Terminate
  else
    FCamera.ProcessKeyDown(AKey);
end;

procedure TDepthTestingApp.KeyUp(const AKey: Integer; const AShift: TShiftState);
begin
  FCamera.ProcessKeyUp(AKey);
end;

procedure TDepthTestingApp.MouseDown(const AButton: TMouseButton;
  const AShift: TShiftState; const AX, AY: Single);
begin
  FCamera.ProcessMouseDown(AX, AY);
end;

procedure TDepthTestingApp.MouseMove(const AShift: TShiftState; const AX, AY: Single);
begin
  FCamera.ProcessMouseMove(AX, AY);
end;

procedure TDepthTestingApp.MouseUp(const AButton: TMouseButton;
  const AShift: TShiftState; const AX, AY: Single);
begin
  FCamera.ProcessMouseUp;
end;

procedure TDepthTestingApp.MouseWheel(const AShift: TShiftState;
  const AWheelDelta: Integer);
begin
  FCamera.ProcessMouseWheel(AWheelDelta);
end;

procedure TDepthTestingApp.Resize(const AWidth, AHeight: Integer);
begin
  inherited;
  if Assigned(FCamera) then
    FCamera.ViewResized(AWidth, AHeight);
end;

procedure TDepthTestingApp.Shutdown;
begin
  { Nothing to do }
end;

procedure TDepthTestingApp.Update(const ADeltaTimeSec, ATotalTimeSec: Double);
var
  Model, View, Projection: TMatrix4;
begin
  FCamera.HandleInput(ADeltaTimeSec);

  { Define the viewport dimensions }
  glViewport(0, 0, Width, Height);

  { Clear the color and depth buffer }
  glClearColor(0.1, 0.1, 0.1, 1.0);
  glClear(GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT);

  { Use corresponding shader when setting uniforms/drawing objects }
  FShader.Use;
  View := FCamera.GetViewMatrix;
  Projection.InitPerspectiveFovRH(Radians(FCamera.Zoom), Width / Height, 0.1, 100.0);

  { Pass matrices to shader }
  FUniformMVP.Apply(View, Projection);

  { Draw 2 cubes }
  FCubeVAO.BeginRender;

  Model.InitTranslation(-1.0, 0.0, -1.0);
  FUniformMVP.Apply(Model);
  FCubeVAO.Render;

  Model.InitTranslation(2.0, 0.0, 0.0);
  FUniformMVP.Apply(Model);
  FCubeVAO.Render;

  FCubeVAO.EndRender;

  { Draw the plane (floor) }
  Model.Init;
  FUniformMVP.Apply(Model);
  FPlaneVAO.Render;
end;

end.
