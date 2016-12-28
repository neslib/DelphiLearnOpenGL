unit App;

{$INCLUDE 'Sample.inc'}

interface

uses
  System.Classes,
  Sample.App;

type
  THelloWindowApp = class(TApplication)
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

{ THelloWindowApp }

procedure THelloWindowApp.Initialize;
begin
  { Not needed in this sample }
end;

procedure THelloWindowApp.KeyDown(const AKey: Integer; const AShift: TShiftState);
begin
  { Terminate app when Esc key is pressed }
  if (AKey = vkEscape) then
    Terminate;
end;

procedure THelloWindowApp.Shutdown;
begin
  { Not needed in this sample }
end;

procedure THelloWindowApp.Update(const ADeltaTimeSec, ATotalTimeSec: Double);
begin
  { Define the viewport dimensions }
  glViewport(0, 0, Width, Height);

  { Render by simply clearing the color buffer }
  glClearColor(0.2, 0.3, 0.3, 1.0);
  glClear(GL_COLOR_BUFFER_BIT);
end;

end.
