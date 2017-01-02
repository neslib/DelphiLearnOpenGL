unit App;

{$INCLUDE 'Sample.inc'}

interface

uses
  System.Classes,
  System.UITypes,
  System.SysUtils,
  System.Generics.Defaults,
  System.Generics.Collections,
  {$INCLUDE 'OpenGL.inc'}
  Neslib.FastMath,
  Sample.Classes,
  Sample.Common,
  Sample.App;

type
  TWindow = record
    Position: TVector3;
    Distance: Single;
  end;

type
  TBlendingSortApp = class(TApplication)
  private
    FCamera: ICamera;
    FShader: IShader;
    FCubeVAO: IVertexArray;
    FPlaneVAO: IVertexArray;
    FTransparentVAO: IVertexArray;
    FUniformMVP: TUniformMVP;
    FUniformTexture1: GLint;
    FCubeTexture: GLuint;
    FFloorTexture: GLuint;
    FTransparentTexture: GLuint;
    FSorted: TArray<TWindow>;
    FComparer: IComparer<TWindow>;
  public
    procedure Initialize; override;
    procedure Update(const ADeltaTimeSec, ATotalTimeSec: Double); override;
    procedure Shutdown; override;
    procedure Resize(const AWidth, AHeight: Integer); override;
    function NeedStencilBuffer: Boolean; override;
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

const
  { Each cube vertex consists of a 3-element position and 2-element texture coordinate.
    Each group of 4 vertices defines a side of a cube. }
  CUBE_VERTICES: array [0..119] of Single = (
    // Positions       // Texture Coords
    -0.5, -0.5, -0.5,  0.0, 0.0,
     0.5, -0.5, -0.5,  1.0, 0.0,
     0.5,  0.5, -0.5,  1.0, 1.0,
    -0.5,  0.5, -0.5,  0.0, 1.0,

    -0.5, -0.5,  0.5,  0.0, 0.0,
     0.5, -0.5,  0.5,  1.0, 0.0,
     0.5,  0.5,  0.5,  1.0, 1.0,
    -0.5,  0.5,  0.5,  0.0, 1.0,

    -0.5,  0.5,  0.5,  1.0, 0.0,
    -0.5,  0.5, -0.5,  1.0, 1.0,
    -0.5, -0.5, -0.5,  0.0, 1.0,
    -0.5, -0.5,  0.5,  0.0, 0.0,

     0.5,  0.5,  0.5,  1.0, 0.0,
     0.5,  0.5, -0.5,  1.0, 1.0,
     0.5, -0.5, -0.5,  0.0, 1.0,
     0.5, -0.5,  0.5,  0.0, 0.0,

    -0.5, -0.5, -0.5,  0.0, 1.0,
     0.5, -0.5, -0.5,  1.0, 1.0,
     0.5, -0.5,  0.5,  1.0, 0.0,
    -0.5, -0.5,  0.5,  0.0, 0.0,

    -0.5,  0.5, -0.5,  0.0, 1.0,
     0.5,  0.5, -0.5,  1.0, 1.0,
     0.5,  0.5,  0.5,  1.0, 0.0,
    -0.5,  0.5,  0.5,  0.0, 0.0);

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
  { Each plane vertex consists of a 3-element position and 2-element texture
    coordinate.
    Note: note we set the texture coordinates higher than 1 that together with
    GL_REPEAT (as texture wrapping mode) will cause the floor texture to
    repeat. }
  PLANE_VERTICES: array [0..19] of Single = (
    // Positions       // Texture Coords
     5.0, -0.5,  5.0,  2.0, 1.0,
    -5.0, -0.5,  5.0,  0.0, 0.0,
    -5.0, -0.5, -5.0,  0.0, 2.0,
     5.0, -0.5, -5.0,  2.0, 2.0);

const
  PLANE_INDICES: array [0..5] of UInt16 = (0, 1, 2, 0, 2, 3);

const
  { Each transparent vertex consists of a 3-element position and 2-element
    texture coordinate.
    Note: texture Y coordinates are swapped because texture is flipped
    upside down }
  TRANSPARENT_VERTICES: array [0..19] of Single = (
    // Positions       // Texture Coords
     0.0,  0.5,  0.0,  0.0, 0.0,
     0.0, -0.5,  0.0,  0.0, 1.0,
     1.0, -0.5,  0.0,  1.0, 1.0,
     1.0,  0.5,  0.0,  1.0, 0.0);

const
  { Positions of window planes }
  WINDOWS: array [0..4] of TVector3 = (
    (X: -1.5; Y: 0.0; Z: -0.48),
    (X:  1.5; Y: 0.0; Z:  0.51),
    (X:  0.0; Y: 0.0; Z:  0.70),
    (X: -0.3; Y: 0.0; Z: -2.30),
    (X:  0.5; Y: 0.0; Z: -0.60));

{ TBlendingSortApp }

procedure TBlendingSortApp.Initialize;
var
  VertexLayout: TVertexLayout;
begin
  { Initialize the asset manager }
  TAssets.Initialize;

  { Setup some OpenGL options }
  glEnable(GL_DEPTH_TEST);
  glEnable(GL_BLEND);
  glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

  { Create camera }
  FCamera := TCamera.Create(Width, Height, Vector3(0, 0, 3));

  { Build and compile our shader program }
  FShader := TShader.Create('shaders/blending_sorted.vs', 'shaders/blending_sorted.fs');
  FUniformMVP.Init(FShader);
  FUniformTexture1 := FShader.GetUniformLocation('texture1');

  { Define layout of the attributes in the shader }
  VertexLayout.Start(FShader)
    .Add('position', 3)
    .Add('texCoords', 2);

  { Create the vertex array for the cube. }
  FCubeVAO := TVertexArray.Create(VertexLayout,
    CUBE_VERTICES, SizeOf(CUBE_VERTICES), CUBE_INDICES);

  { Create the vertex array for the plane.
    It uses the same vertex layout as the cube. }
  FPlaneVAO := TVertexArray.Create(VertexLayout,
    PLANE_VERTICES, SizeOf(PLANE_VERTICES), PLANE_INDICES);

  { Create the vertex array for the transparent plane (window).
    It uses the same vertex layout as the cube and the same indices as the plane. }
  FTransparentVAO := TVertexArray.Create(VertexLayout,
    TRANSPARENT_VERTICES, SizeOf(TRANSPARENT_VERTICES), PLANE_INDICES);

  { Load textures }
  FCubeTexture := LoadTexture('textures/marble.jpg');
  FFloorTexture := LoadTexture('textures/metal.png');
  FTransparentTexture := LoadTexture('textures/window.png', True);

  { Setup sorting.
    Create a comparer to sort windows by their distance from the camera,
    longest distance (furthest object) first. }
  SetLength(FSorted, Length(WINDOWS));
  FComparer := TComparer<TWindow>.Construct(
    function(const Left, Right: TWindow): Integer
    begin
      if (Left.Distance > Right.Distance) then
        Result := -1
      else if (Left.Distance < Right.Distance) then
        Result := 1
      else
        Result := 0;
    end);
end;

procedure TBlendingSortApp.KeyDown(const AKey: Integer; const AShift: TShiftState);
begin
  if (AKey = vkEscape) then
    { Terminate app when Esc key is pressed }
    Terminate
  else
    FCamera.ProcessKeyDown(AKey);
end;

procedure TBlendingSortApp.KeyUp(const AKey: Integer; const AShift: TShiftState);
begin
  FCamera.ProcessKeyUp(AKey);
end;

procedure TBlendingSortApp.MouseDown(const AButton: TMouseButton;
  const AShift: TShiftState; const AX, AY: Single);
begin
  FCamera.ProcessMouseDown(AX, AY);
end;

procedure TBlendingSortApp.MouseMove(const AShift: TShiftState; const AX, AY: Single);
begin
  FCamera.ProcessMouseMove(AX, AY);
end;

procedure TBlendingSortApp.MouseUp(const AButton: TMouseButton;
  const AShift: TShiftState; const AX, AY: Single);
begin
  FCamera.ProcessMouseUp;
end;

procedure TBlendingSortApp.MouseWheel(const AShift: TShiftState;
  const AWheelDelta: Integer);
begin
  FCamera.ProcessMouseWheel(AWheelDelta);
end;

function TBlendingSortApp.NeedStencilBuffer: Boolean;
begin
  Result := True;
end;

procedure TBlendingSortApp.Resize(const AWidth, AHeight: Integer);
begin
  inherited;
  if Assigned(FCamera) then
    FCamera.ViewResized(AWidth, AHeight);
end;

procedure TBlendingSortApp.Shutdown;
begin
  glDeleteTextures(1, @FCubeTexture);
  glDeleteTextures(1, @FFloorTexture);
  glDeleteTextures(1, @FTransparentTexture);
end;

procedure TBlendingSortApp.Update(const ADeltaTimeSec, ATotalTimeSec: Double);
var
  Model, View, Projection: TMatrix4;
  I: Integer;
begin
  FCamera.HandleInput(ADeltaTimeSec);

  { Define the viewport dimensions }
  glViewport(0, 0, Width, Height);

  { Clear the color and depth buffer }
  glClearColor(0.1, 0.1, 0.1, 1.0);
  glClear(GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT);

  { Sort the windows by distance }
  for I := 0 to Length(WINDOWS) - 1 do
  begin
    FSorted[I].Position := WINDOWS[I];

    { Note that we use DistanceSquared instead of Distance. Since we don't care
      about the actual distance, but only want to compare distances, it is more
      efficient to use DistanceSquared (since it avoids calculating a square
      root) }
    FSorted[I].Distance := FCamera.Position.DistanceSquared(WINDOWS[I]);
  end;
  TArray.Sort<TWindow>(FSorted, FComparer);

  { Use corresponding shader when setting uniforms/drawing objects }
  FShader.Use;
  View := FCamera.GetViewMatrix;
  Projection.InitPerspectiveFovRH(Radians(FCamera.Zoom), Width / Height, 0.1, 100.0);
  FUniformMVP.Apply(View, Projection);

  { Draw cubes }
  FCubeVAO.BeginRender;

  glBindTexture(GL_TEXTURE_2D, FCubeTexture);
  Model.InitTranslation(-1.0, 0.0, -1.0);
  FUniformMVP.Apply(Model);
  FCubeVAO.Render;

  Model.InitTranslation(2.0, 0.0, 0.0);
  FUniformMVP.Apply(Model);
  FCubeVAO.Render;

  FCubeVAO.EndRender;

  { Draw floor  }
  glBindTexture(GL_TEXTURE_2D, FFloorTexture);
  Model.Init;
  FUniformMVP.Apply(Model);
  FPlaneVAO.Render;

  { Draw windows }
  glBindTexture(GL_TEXTURE_2D, FTransparentTexture);
  FTransparentVAO.BeginRender;

  for I := 0 to Length(FSorted) - 1 do
  begin
    Model.InitTranslation(FSorted[I].Position);
    FUniformMVP.Apply(Model);
    FTransparentVAO.Render;
  end;
  FTransparentVAO.EndRender;
end;

end.
