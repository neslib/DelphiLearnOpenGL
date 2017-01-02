unit Sample.App;

{$INCLUDE 'Sample.inc'}

interface

uses
  System.Classes,
  System.UITypes;

type
  { Abstract base class for sample applications.

    Note that the sample applications do NOT use the VCL or FireMonkey
    frameworks. So you can also use these samples to learn how to make a
    cross-platform without FireMonkey. See the Sample.Platform.* units for
    details. }
  TApplication = class abstract
  {$REGION 'Internal Declarations'}
  private
    FWidth: Integer;
    FHeight: Integer;
    FTitle: String;
  {$ENDREGION 'Internal Declarations'}
  public
    { Creates the sample application.

      Parameters:
        AWidth: width of the client area of the window.
        AHeight: height of the client area of the window.
        ATitle: title of the application.

      These parameters are ignored on mobile platforms (which is always full
      screen) }
    constructor Create(const AWidth, AHeight: Integer; const ATitle: String); virtual;

    { Must be overridden to initialize the application. For example, you can
      load resources such as buffers, textures, shaders etc. here }
    procedure Initialize; virtual; abstract;

    { Is called once every frame to update state and render a frame.
      Must be overridden.

      Parameters:
        ADeltaTimeSec: time since last Update call in seconds.
        ATotalTimeSec: time since the app started, in seconds }
    procedure Update(const ADeltaTimeSec, ATotalTimeSec: Double); virtual; abstract;

    { Must be overridden to clean up the app. Is called when the application
      terminates. Any resources created in the Initialize method should be
      released here. }
    procedure Shutdown; virtual; abstract;

    { Is called when a mouse button is pressed (or screen touch is started).

      Parameters:
        AButton: the mouse button that is pressed (touch events are translated
          to the mbLeft button).
        AShift: shift state (whether Shift and/or Control are down)
        AX: X-position
        AY: Y-position

      This method does nothing by default but can be overridden to handle a
      mouse press or touch event. }
    procedure MouseDown(const AButton: TMouseButton; const AShift: TShiftState;
      const AX, AY: Single); virtual;

    { Is called when the mouse is moved (or the finger on the touch screen is
      moved).

      Parameters:
        AShift: shift state (whether Shift and/or Control are down)
        AX: X-position
        AY: Y-position

      This method does nothing by default but can be overridden to handle a
      mouse move or touch event. }
    procedure MouseMove(const AShift: TShiftState; const AX, AY: Single); virtual;

    { Is called when a mouse button is released (or screen touch is ended).

      Parameters:
        AButton: the mouse button that is released (touch events are translated
          to the mbLeft button).
        AShift: shift state (whether Shift and/or Control are down)
        AX: X-position
        AY: Y-position

      This method does nothing by default but can be overridden to handle a
      mouse release or touch event. }
    procedure MouseUp(const AButton: TMouseButton; const AShift: TShiftState;
      const AX, AY: Single); virtual;

    { Is called when the mouse wheel is moved.

      Parameters:
        AShift: shift state (whether Shift and/or Control are down)
        AWheelDelta: number of notches the wheel is moved.

      This method does nothing by default but can be overridden to handle a
      mouse wheel event. }
    procedure MouseWheel(const AShift: TShiftState; const AWheelDelta: Integer); virtual;

    { Is called when a key is depressed.

      Parameters:
        AKey: virtual key code (one of the vk* constants in the System.UITypes
          unit)
        AShift: shift state (whether Shift, Control and or Alt are down)

      This method does nothing by default but can be overridden to handle a key
      press. }
    procedure KeyDown(const AKey: Integer; const AShift: TShiftState); virtual;

    { Is called when a key is released.

      Parameters:
        AKey: virtual key code (one of the vk* constants in the System.UITypes
          unit)
        AShift: shift state (whether Shift, Control and or Alt are down)

      This method does nothing by default but can be overridden to handle a key
      release. }
    procedure KeyUp(const AKey: Integer; const AShift: TShiftState); virtual;

    { Is called when the framebuffer has resized. For example, when the user
      rotates a mobile device.

      Parameters:
        AWidth: new width of the framebuffer
        AHeight: new height of the framebuffer }
    procedure Resize(const AWidth, AHeight: Integer); virtual;

    { If the application needs a stencil buffer, then you must override this
      method and return True. Returns False by default. }
    function NeedStencilBuffer: Boolean; virtual;

    { Call this method to manually terminate the app. }
    procedure Terminate;

    { Framebuffer width }
    property Width: Integer read FWidth;

    { Framebuffer height }
    property Height: Integer read FHeight;

    { Application title }
    property Title: String read FTitle;
  end;
  TApplicationClass = class of TApplication;

{ Main entry point of the application. Call this procedure to run the app.

  Parameters:
    AAppClass: class of the application to run. This should the class you
      derived from TApplication.
    AWidth: width of the client area of the window.
    AHeight: height of the client area of the window.
    ATitle: title of the application. }
procedure RunApp(const AAppClass: TApplicationClass; const AWidth,
  AHeight: Integer; const ATitle: String);

implementation

uses
  Sample.Platform;

procedure RunApp(const AAppClass: TApplicationClass; const AWidth,
  AHeight: Integer; const ATitle: String);
var
  App: TApplication;
begin
  ReportMemoryLeaksOnShutdown := True;
  App := AAppClass.Create(AWidth, AHeight, ATitle);
  try
    TPlatform.Run(App);
  finally
    App.Free;
  end;
end;

{ TApplication }

constructor TApplication.Create(const AWidth, AHeight: Integer;
  const ATitle: String);
begin
  inherited Create;
  FWidth := AWidth;
  FHeight := AHeight;
  FTitle := ATitle;
end;

procedure TApplication.KeyDown(const AKey: Integer; const AShift: TShiftState);
begin
  { No default implementation }
end;

procedure TApplication.KeyUp(const AKey: Integer; const AShift: TShiftState);
begin
  { No default implementation }
end;

procedure TApplication.MouseDown(const AButton: TMouseButton;
  const AShift: TShiftState; const AX, AY: Single);
begin
  { No default implementation }
end;

procedure TApplication.MouseMove(const AShift: TShiftState; const AX,
  AY: Single);
begin
  { No default implementation }
end;

procedure TApplication.MouseUp(const AButton: TMouseButton;
  const AShift: TShiftState; const AX, AY: Single);
begin
  { No default implementation }
end;

procedure TApplication.MouseWheel(const AShift: TShiftState;
  const AWheelDelta: Integer);
begin
  { No default implementation }
end;

function TApplication.NeedStencilBuffer: Boolean;
begin
  Result := False;
end;

procedure TApplication.Resize(const AWidth, AHeight: Integer);
begin
  FWidth := AWidth;
  FHeight := AHeight;
end;

procedure TApplication.Terminate;
begin
  TPlatform.Terminate;
end;

end.
