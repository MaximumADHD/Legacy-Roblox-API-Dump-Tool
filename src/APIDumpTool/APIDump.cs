using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Data;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.IO.Compression;
using System.Linq;
using System.Net;
using System.Text;
using System.Threading.Tasks;
using System.Windows.Forms;
using System.Xml;
using LuaInterface;

namespace APIDumpTool
{

    public partial class APIDump : Form
    {
        private WebClient http = new WebClient();

        public APIDump()
        {
            InitializeComponent();
        }

        public async Task setStatus(string statusText = "")
        {
            if (!statusText.Equals(""))
            {
                statusText += "...";
            }
            status.Text = statusText;
            await Task.Delay(100);
        }

        public void createDirectory(string directory)
        {
            if (!Directory.Exists(directory))
            {
                Directory.CreateDirectory(directory);
            }
        }

        public async Task extractRobloxZip(string database, string version, string fileName, string directory)
        {
            WebClient localHttp = new WebClient();
            string url = database + version + "-" + fileName;
            await setStatus("Fetching " + fileName);
            byte[] file = localHttp.DownloadData(url);
            string filePath = Path.Combine(directory, fileName);
            await setStatus("Writing " + fileName);
            FileStream writeFile = File.Create(filePath);
            writeFile.Write(file, 0, file.Length);
            writeFile.Close();
            ZipArchive archive = ZipFile.Open(filePath,ZipArchiveMode.Read);
            foreach (ZipArchiveEntry entry in archive.Entries)
            {
                string entryName = entry.FullName;
                await setStatus("Extracting " + entryName);
                string relativePath = Path.Combine(directory,entryName);
                if (!File.Exists(relativePath))
                {
                    entry.ExtractToFile(relativePath);
                }
            }
        }

        public async Task<string> loadRobloxBuild(string database, string version, string directory)
        {
            await setStatus("Building directory for " + version);
            string directoryPath = Path.Combine(directory, version);
            createDirectory(directoryPath);
            // There are two directories that need to exist in order to get the application to cooperate.
            // content, and PlatformContent/pc
            string content = Path.Combine(directoryPath, "content");
            createDirectory(content);
            string platformContent = Path.Combine(directoryPath, "PlatformContent", "pc");
            createDirectory(platformContent);
            // Write AppSettings (required to get RobloxPlayerBeta to cooperate)
            string appSettings = Path.Combine(directoryPath, "AppSettings.xml");
            File.WriteAllText(appSettings, "<Settings><ContentFolder>content</ContentFolder><BaseUrl>http://www.roblox.com</BaseUrl></Settings>");
            // Extract RobloxApp.zip and Libraries.zip from ROBLOX's setup cdn into our directory.
            await extractRobloxZip(database, version, "RobloxApp.zip", directoryPath);
            await extractRobloxZip(database, version, "Libraries.zip", directoryPath);
            // Return the path to RobloxPlayerBeta.exe
            return Path.Combine(directoryPath, "RobloxPlayerBeta.exe");
        }

        public async Task<string> getAPIFile(string database = "")
        {
            this.Enabled = false;
            if (database.Equals(""))
            {
                database = comboBox1.Text;
            }
            database = "http://setup." + database + ".com/";
            Console.WriteLine(database);
            string version = http.DownloadString(database + "version.txt");
            string apiDumps = Path.Combine(Environment.GetEnvironmentVariable("LocalAppData"), "Roblox API Dumps");
            createDirectory(apiDumps);
            string filePath = Path.Combine(apiDumps, version) + ".txt";
            if (!File.Exists(filePath))
            {
                string buildDir = Path.Combine(apiDumps,"Builds");
                createDirectory(buildDir);
                string robloxPlayerBeta = await loadRobloxBuild(database, version, buildDir);
                Console.WriteLine(robloxPlayerBeta);
                await setStatus("Extracting API Dump");
                Process apiDump = Process.Start(robloxPlayerBeta, "--API api.txt");
                apiDump.WaitForExit();
                await setStatus("Writing API Dump");
                string dumpPath = robloxPlayerBeta.Replace("RobloxPlayerBeta.exe", "api.txt");
                File.Copy(dumpPath, filePath);
            }
            else
            {
                await setStatus("API Dump already generated!");
            }
            this.Enabled = true;
            return filePath;
        }

        public string compareAPIDumps(string apiDump0, string apiDump1)
        {
            string result = "";
            try
            {
                Lua parser = new Lua();
                parser.DoString("PRODUCTION_API_DUMP = [===[" + apiDump0 + "]===]");
                parser.DoString("GAMETEST_API_DUMP = [===[" + apiDump1 + "]===]");
                string currentDir = Directory.GetCurrentDirectory();
                string luaFilePath = Path.Combine(currentDir, "CompareToProduction.lua");
                string luaFile = File.ReadAllText(luaFilePath);
                parser.DoString(luaFile);
                result = parser.GetString("FINAL_RESULT");
            }
            catch
            {
                result = "FAIL";
                MessageBox.Show("Failed to compare API Dumps!","Error",MessageBoxButtons.OK,MessageBoxIcon.Error);
            }
            return result;
        }

        private void comboBox1_SelectedIndexChanged(object sender, EventArgs e)
        {
            button1.Enabled = true;
            button2.Enabled = true;
        }

        private async void button1_Click(object sender, EventArgs e)
        {
            string filePath = await getAPIFile();
            Process.Start(filePath);
            await setStatus();
        }

        private async void button2_Click(object sender, EventArgs e)
        {
            this.Enabled = false;
            if (!comboBox1.Text.Equals("roblox"))
            {
                await setStatus("Getting gametest API Dump...");
                string gametestBuild = File.ReadAllText(await getAPIFile());
                await setStatus("Getting production API Dump...");
                string robloxBuild = File.ReadAllText(await getAPIFile("roblox"));
                await setStatus("Fetching results");
                string result = compareAPIDumps(robloxBuild, gametestBuild);
                if (result != "FAIL")
                {
                    if (result == "")
                    {
                        MessageBox.Show("No differences were found :(", "No results", MessageBoxButtons.OK, MessageBoxIcon.Information);
                    }
                    else
                    {
                        try
                        {
                            string apiDumps = Path.Combine(Environment.GetEnvironmentVariable("LocalAppData"), "Roblox API Dumps");
                            string file = Path.Combine(apiDumps, comboBox1.Text + "_diff.txt");
                            File.WriteAllText(file, result);
                            Process.Start(file);
                        }
                        catch
                        {
                            status.Text = "Couldn't write to file. Probably open in text editor.";
                        }
                    }
                }
                await setStatus("");
            }
            else
            {
                MessageBox.Show("You cannot compare the production API Dump to itself!","Error",MessageBoxButtons.OK,MessageBoxIcon.Error);
            }
            this.Enabled = true;
        }
    }
}