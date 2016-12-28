unit App;

{$INCLUDE 'Sample.inc'}

interface

uses
  System.Classes,
  Sample.Classes,
  Sample.App;

type
  TShadersApp = class(TApplication)
  private
    FShader: IShader;
    FVertexArray: IVertexArray;
  public
    procedure Initialize; override;
    procedure Update(const ADeltaTimeSec, ATotalTimeSec: Double); override;
    procedure Shutdown; override;
    procedure KeyDown(const AKey: Integer; const AShift: TShiftState); override;
  end;

implementation

uses
  {$INCLUDE 'OpenGL.inc'}
  System.UITypes;

const
  { Each vertex consists of a 3-element position and 3-element color. }
  VERTICES: array [0..17] of Single = (
    // Positions      // Colors
    0.5, -0.5, 0.0,   1.0, 0.0, 0.0,  // Bottom Right
   -0.5, -0.5, 0.0,   0.0, 1.0, 0.0,  // Bottom Left
    0.0,  0.5, 0.0,   0.0, 0.0, 1.0); // Top

const
  { The indices define a single triangle }
  INDICES: array [0..2] of UInt16 = (0, 1, 2);

{ TShadersApp }

procedure TShadersApp.Initialize;
var
  VertexLayout: TVertexLayout;
begin
  { Initialize the asset manager }
  TAssets.Initialize;

  { Build and compile our shader program }
  FShader := TShader.Create('shaders/basic.vs', 'shaders/basic.fs');

  { Define layout of the attributes in the shader program. The shader program
    contains 2 attributes called "position" and "color". Both attributes are of
    type "vec3" and thus contain 3 floating-point values. }
  VertexLayout.Start(FShader)
    .Add('position', 3)
    .Add('color', 3);

  { Create the vertex array }
  FVertexArray := TVertexArray.Create(VertexLayout,
    VERTICES, SizeOf(VERTICES), INDICES);
end;

procedure TShadersApp.KeyDown(const AKey: Integer; const AShift: TShiftState);
begin
  { Terminate app when Esc key is pressed }
  if (AKey = vkEscape) then
    Terminate;
end;

procedure TShadersApp.Shutdown;
begin
  { Not needed in this sample }
end;

procedure TShadersApp.Update(const ADeltaTimeSec, ATotalTimeSec: Double);
begin
  { Define the viewport dimensions }
  glViewport(0, 0, Width, Height);

  { Clear the color buffer }
  glClearColor(0.2, 0.3, 0.3, 1.0);
  glClear(GL_COLOR_BUFFER_BIT);

  { Draw the triangle }
  FShader.Use;
  FVertexArray.Render;
end;

end.
