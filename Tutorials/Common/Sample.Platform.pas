unit Sample.Platform;

{$INCLUDE 'Sample.inc'}

interface

uses
  Sample.App;

type
  { Static base class for platform-specific functionality. For every platform
    (Windows, MacOS, iOS and Android), there is a derived class. }
  TPlatformBase = class abstract // static
  {$REGION 'Internal Declarations'}
  private class var
    FApp: TApplication;
    FFrameCount: Integer;
    FFPS: Integer;
    FSecondsPerTick: Double;
    FStartTicks: Int64;
    FLastUpdateTicks: Int64;
    FFPSTicks: Int64;
    FScreenScale: Single;
    FTerminated: Boolean;
  protected
    class procedure StartClock; static;
    class procedure Update; static;
  {$ENDREGION 'Internal Declarations'}
  protected
    { Must be overridden to run the application. }
    class procedure DoRun; virtual; abstract;

    { Is set to True to request to app to terminate }
    class property Terminated: Boolean read FTerminated write FTerminated;
  public
    { Runs the application. }
    class procedure Run(const AApp: TApplication); static;

    { Call this method to manually terminate the app. }
    class procedure Terminate; static;

    { The application }
    class property App: TApplication read FApp;

    { Current render framerate in Frames Per Second. }
    class property RenderFramerate: Integer read FFPS;

    { Screen scale factor. Will be 1.0 on "normal" density displays, or greater
      than 1.0 on high density displays (like Retina displays) }
    class property ScreenScale: Single read FScreenScale write FScreenScale;
  end;
  TPlaformClass = class of TPlatformBase;

var
  { Actual platform class. For example, on Windows this will be TPlatformWindows }
  TPlatform: TPlaformClass = nil;

implementation

uses
  System.Diagnostics,
  {$IF Defined(MSWINDOWS)}
  Sample.Platform.Windows;
  {$ELSEIF Defined(IOS)}
  Sample.Platform.iOS;
  {$ELSEIF Defined(ANDROID)}
  Sample.Platform.Android;
  {$ELSEIF Defined(MACOS)}
  Sample.Platform.Mac;
  {$ELSE}
    {$MESSAGE Error 'Unsupported platform'}
  {$ENDIF}

{ TPlatformBase }

class procedure TPlatformBase.Run(const AApp: TApplication);
begin
  FApp := AApp;
  FScreenScale := 1.0;
  TPlatform.DoRun;
end;

class procedure TPlatformBase.StartClock;
begin
  { Create a clock for measuring framerate }
  if (FSecondsPerTick = 0) then
  begin
    TStopwatch.Create; // Make sure frequency is initialized
    FSecondsPerTick := 1 / TStopwatch.Frequency;
  end;
  FStartTicks := TStopwatch.GetTimeStamp;
  FLastUpdateTicks := FStartTicks;
  FFPSTicks := FStartTicks;
end;

class procedure TPlatformBase.Terminate;
begin
  FTerminated := True;
end;

class procedure TPlatformBase.Update;
var
  Ticks: Int64;
  DeltaSec, TotalSec: Double;
begin
  { Calculate time since last Update call }
  Ticks := TStopwatch.GetTimeStamp;
  DeltaSec := (Ticks - FLastUpdateTicks) * FSecondsPerTick;
  TotalSec := (Ticks - FStartTicks) * FSecondsPerTick;
  FLastUpdateTicks := Ticks;

  { Update the application (which should render a frame) }
  App.Update(DeltaSec, TotalSec);

  { Calculate framerate }
  Inc(FFrameCount);
  if ((Ticks - FFPSTicks) >= TStopwatch.Frequency) then
  begin
    FFPS := FFrameCount;
    FFrameCount := 0;
    Inc(FFPSTicks, TStopwatch.Frequency);
  end;
end;

initialization
  {$IF Defined(MSWINDOWS)}
  TPlatform := TPlatformWindows;
  {$ELSEIF Defined(IOS)}
  TPlatform := TPlatformIOS;
  {$ELSEIF Defined(ANDROID)}
  TPlatform := TPlatformAndroid;
  {$ELSEIF Defined(MACOS)}
  TPlatform := TPlatformMac;
  {$ENDIF}

end.
