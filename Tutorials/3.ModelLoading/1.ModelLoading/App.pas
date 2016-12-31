unit App;

{$INCLUDE 'Sample.inc'}

interface

uses
  System.Classes,
  System.UITypes,
  System.SysUtils,
  {$INCLUDE 'OpenGL.inc'}
  Neslib.FastMath,
  Sample.Classes,
  Sample.App;

type
  { Combines all uniforms for Model, View and Projection matrices }
  TUniformMVP = record
  public
    Model: GLint;
    View: GLint;
    Projection: GLint;
  public
    { Retrieves the uniform locations from the given shader }
    procedure Init(const AShader: IShader);

    { Sets the uniform values for the currently active shader }
    procedure Apply(const AModel: TMatrix4); overload;
    procedure Apply(const AView, AProjection: TMatrix4); overload;
  end;

type
  TModelLoadingApp = class(TApplication)
  private
    FCamera: ICamera;
    FShader: IShader;
    FUniformMVP: TUniformMVP;
    FOurModel: IModel;
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

{ TModelLoadingApp }

procedure TModelLoadingApp.Initialize;
begin
  { Initialize the asset manager }
  TAssets.Initialize;

  { Enable depth testing }
  glEnable(GL_DEPTH_TEST);

  { Create camera }
  FCamera := TCamera.Create(Width, Height, Vector3(0, 0, 3));

  { Build and compile our shader programs }
  FShader := TShader.Create('shaders/shader.vs', 'shaders/shader.fs');
  FUniformMVP.Init(FShader);

  { Load model }
  FOurModel := TModel.Create('models/nanosuit.obj', FShader);

  { Build the "Release | Wireframe" configuration to render wireframe polygons. }
  {$IF Defined(WIREFRAME) and not Defined(MOBILE)}
  glPolygonMode(GL_FRONT_AND_BACK, GL_LINE);
  {$ENDIF}
end;

procedure TModelLoadingApp.KeyDown(const AKey: Integer; const AShift: TShiftState);
begin
  if (AKey = vkEscape) then
    { Terminate app when Esc key is pressed }
    Terminate
  else
    FCamera.ProcessKeyDown(AKey);
end;

procedure TModelLoadingApp.KeyUp(const AKey: Integer; const AShift: TShiftState);
begin
  FCamera.ProcessKeyUp(AKey);
end;

procedure TModelLoadingApp.MouseDown(const AButton: TMouseButton;
  const AShift: TShiftState; const AX, AY: Single);
begin
  FCamera.ProcessMouseDown(AX, AY);
end;

procedure TModelLoadingApp.MouseMove(const AShift: TShiftState; const AX, AY: Single);
begin
  FCamera.ProcessMouseMove(AX, AY);
end;

procedure TModelLoadingApp.MouseUp(const AButton: TMouseButton;
  const AShift: TShiftState; const AX, AY: Single);
begin
  FCamera.ProcessMouseUp;
end;

procedure TModelLoadingApp.MouseWheel(const AShift: TShiftState;
  const AWheelDelta: Integer);
begin
  FCamera.ProcessMouseWheel(AWheelDelta);
end;

procedure TModelLoadingApp.Resize(const AWidth, AHeight: Integer);
begin
  inherited;
  if Assigned(FCamera) then
    FCamera.ViewResized(AWidth, AHeight);
end;

procedure TModelLoadingApp.Shutdown;
begin
  { Nothing to do }
end;

procedure TModelLoadingApp.Update(const ADeltaTimeSec, ATotalTimeSec: Double);
var
  Model, View, Projection, Translate, Scale: TMatrix4;
begin
  FCamera.HandleInput(ADeltaTimeSec);

  { Define the viewport dimensions }
  glViewport(0, 0, Width, Height);

  { Clear the color and depth buffer }
  glClearColor(0.05, 0.05, 0.05, 1.0);
  glClear(GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT);

  { Use shader }
  FShader.Use;

  { Create camera transformation }
  View := FCamera.GetViewMatrix;
  Projection.InitPerspectiveFovRH(Radians(FCamera.Zoom), Width / Height, 0.1, 100.0);

  { Pass matrices to shader }
  FUniformMVP.Apply(View, Projection);

  { Create Model matrix }
  { Translate it down a bit so it's at the center of the scene }
  Translate.InitTranslation(0.0, -1.75, 0.0);

  { It's a bit too big for our scene, so scale it down }
  Scale.InitScaling(0.2);
  Model := Scale * Translate;
  FUniformMVP.Apply(Model);

  { Draw the model }
  FOurModel.Draw;
end;

{ TUniformMVP }

procedure TUniformMVP.Apply(const AView, AProjection: TMatrix4);
begin
  glUniformMatrix4fv(View, 1, GL_FALSE, @AView);
  glUniformMatrix4fv(Projection, 1, GL_FALSE, @AProjection);
end;

procedure TUniformMVP.Apply(const AModel: TMatrix4);
begin
  glUniformMatrix4fv(Model, 1, GL_FALSE, @AModel);
end;

procedure TUniformMVP.Init(const AShader: IShader);
begin
  Model := AShader.GetUniformLocation('model');
  View := AShader.GetUniformLocation('view');
  Projection := AShader.GetUniformLocation('projection');
end;

end.
