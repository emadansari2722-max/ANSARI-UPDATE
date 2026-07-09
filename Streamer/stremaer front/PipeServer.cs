using System;
using System.IO;
using System.IO.Pipes;
using System.Text;
using System.Threading.Tasks;

namespace AotForms
{
    public static class PipeServer
    {
        public static void Start()
        {
            Task.Run(() =>
            {
                while (true)
                {
                    try
                    {
                        using var server = new NamedPipeServerStream("esp_pipe", PipeDirection.In, 1, PipeTransmissionMode.Byte, PipeOptions.Asynchronous);
                        server.WaitForConnection();

                        using var reader = new StreamReader(server, Encoding.UTF8);
                        string? command = reader.ReadLine();

                        if (string.IsNullOrWhiteSpace(command)) continue;

                        // Some writers may include a null terminator; normalize it away.
                        string normalized = command.Replace("\0", string.Empty).Trim();
                        if (string.IsNullOrWhiteSpace(normalized)) continue;

                        switch (normalized)
                        {
                            case "aimbotvisible":
                                Config.AimbotVisible = true;
                                break;

                            case "aimbotvisibleoff":
                                Config.AimbotVisible = false;
                                break;

                            case "enablefunction":
                                Config.enableAimBot = true;
                                break;

                            case "enablefunctionoff":
                                Config.enableAimBot = false;
                                break;

                            case "aimbotrage":
                                Config.AimBotRage = true;
                                break;

                            case "aimbotrageoff":
                                Config.AimBotRage = false;
                                break;

                            case "silentaim":
                                Config.SilentAim = true;
                                break;

                            case "silentaimoff":
                                Config.SilentAim = false;
                                break;

                            case "upplayer":
                                Config.UpPlayer = true;
                                break;

                            case "upplayeroff":
                                Config.UpPlayer = false;
                                break;

                            case "telekil":
                                Config.teli = true;
                                break;

                            case "telekiloff":
                                Config.teli = false;
                                break;

                            case "drawfov":
                                Config.FOVEnabled = true;
                                break;

                            case "drawfovoff":
                                Config.FOVEnabled = false;
                                break;

                            case "espline":
                                Config.ESPLine = true;
                                break;

                            case "esplineoff":
                                Config.ESPLine = false;
                                break;

                            case "espbox":
                                Config.ESPBox = true;
                                break;

                            case "espboxoff":
                                Config.ESPBox = false;
                                break;

                            case "esphealth":
                                Config.ESPHealth = true;
                                break;

                            case "esphealthoff":
                                Config.ESPHealth = false;
                                break;

                            case "espname":
                                Config.ESPName = true;
                                break;

                            case "espnameoff":
                                Config.ESPName = false;
                                break;

                            case "espskeleton":
                                Config.ESPSkeleton = true;
                                break;

                            case "espskeletonoff":
                                Config.ESPSkeleton = false;
                                break;

                            case "espaimtrack":
                                Config.AimTrackLine = true;
                                break;

                            case "espaimtrackoff":
                                Config.AimTrackLine = false;
                                break;

                            case "streammode":
                                Config.StreamMode = true;
                                break;

                            case "streammodeoff":
                                Config.StreamMode = false;
                                break;

                            case "norecoil":
                                Config.NoRecoil = true;
                                break;

                            case "norecoiloff":
                                Config.NoRecoil = false;
                                break;

                            default:
                                if (normalized.StartsWith("silentaim_mode:"))
                                {
                                    string indexStr = normalized.Split(':')[1];
                                    if (int.TryParse(indexStr, out int modeIndex))
                                    {
                                        Config.AimBotType = (AimBotType)modeIndex;
                                        Console.WriteLine($"SilentAim mode set to index: {modeIndex}");
                                    }
                                }
                                else if (normalized.StartsWith("aimfov:"))
                                {
                                    string value = normalized.Split(':')[1];
                                    if (float.TryParse(value, out float fov))
                                    {
                                        Config.AimFov = fov;
                                        Console.WriteLine($"Aim FOV set to: {fov}");
                                    }
                                }
                                else
                                {
                                    Console.WriteLine($"Unknown command: {normalized}");
                                }
                                break;
                        }
                    }
                    catch (Exception ex)
                    {
                        Console.WriteLine($"Pipe error: {ex.Message}");
                    }
                }
            });
        }
    }
}

