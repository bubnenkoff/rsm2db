import std.stdio;
import std.file;
import std.path;
import std.string;
import std.array;
import std.algorithm;
import std.conv;

import ddbc.all;

import rsmparser;

import datastruct; // structure of our data


MyData [] mds;
	
string imgFoldersPath = `D:\code\geoportal\exmapleIMG\321\`;

void main()
{

	RSMProcessing();

}

void RSMProcessing()
{
	scope(failure) writeln("[ERROR] Error in RSMProcessing");
	
	if(!imgFoldersPath.exists)
	{
		writeln("[ERROR] Dir do not exists: ", imgFoldersPath);
		return;
	}
	
	auto allDirs = dirEntries(imgFoldersPath, SpanMode.depth).filter!(name => name.isDir);
	string [] dirsWithRSM;

	string [] jpgIMGList; // collecting it after scanning every RSM folder

	// DIR SCANNING SECTION _NO PROCESSING RSM_
	// Обходим все папки и выбираем папки в которых есть RSM
	foreach (dir; allDirs)
	{
		auto rsmfiles = dirEntries(dir, SpanMode.shallow).filter!(f => f.name.endsWith(".rsm"));
		foreach (rsmfile; rsmfiles)
		{
			dirsWithRSM ~= dir;
			break; // prevent multiple additional
		}
	}



	int dirsWithRSMCount;
	int jpgCount;
	// Now scan dirs With RSM and process SINGLE RSM inside
	foreach(dir;dirsWithRSM)
	{
		writeln("iteration dir: ", dir);
		
		dirsWithRSMCount++;

		MyData md;
		auto RSMFullNames = dirEntries(dir, SpanMode.shallow).filter!(f => f.name.endsWith(".rsm"));
		try
		{
		
			foreach(rsmfile; RSMFullNames) // SINGLE RSM IN FOLDER
			{
				string [] coordinates;
				string episodeDate; // from RSM

				auto ini = Ini.Parse(rsmfile);

				md.episodeDate ~= ini["SESSION"].getKey("dEpisodeDate").replace(`/`,``);
				
				
				
				// DIRTY HACK START
					auto myrsm = File(rsmfile);
				
					string x_nLatLT;
					string x_nLongLT;
					
					string x_nLatRT;
					string x_nLongRT;
					
					string x_nLatRB;
					string x_nLongRB;
					
					string x_nLatLB;
					string x_nLongLB;

					foreach(line; myrsm.byLine)
					{
						
						if(line.canFind("nLatLT"))
						{
							x_nLatLT = to!string(line.split("=")[1].split(";")[0]);
						}
						
						
						if(line.canFind("nLongLT"))
						{
							x_nLongLT = to!string(line.split("=")[1].split(";")[0]);
						}	
					
						
						if(line.canFind("nLatRT"))
						{
							x_nLatRT = to!string(line.split("=")[1].split(";")[0]);
						}		
						
						
						if(line.canFind("nLongRT"))
						{
							x_nLongRT = to!string(line.split("=")[1].split(";")[0]);
						}
						
						
						if(line.canFind("nLatRB"))
						{
							x_nLatRB = to!string(line.split("=")[1].split(";")[0]);
						}	

						
						if(line.canFind("nLongRB"))
						{
							x_nLongRB = to!string(line.split("=")[1].split(";")[0]);
						}	

						
						if(line.canFind("nLatLB"))
						{
							x_nLatLB = to!string(line.split("=")[1].split(";")[0]);
						}	

						
						if(line.canFind("nLongLB"))
						{
							x_nLongLB = to!string(line.split("=")[1].split(";")[0]);
						}	

					}
					
					coordinates ~= x_nLatLT ~ ` ` ~ x_nLongLT;
					coordinates ~= x_nLatRT ~ ` ` ~ x_nLongRT;
					coordinates ~= x_nLatRB ~ ` ` ~ x_nLongRB;
					coordinates ~= x_nLatLB ~ ` ` ~ x_nLongLB;
					coordinates ~= x_nLatLT ~ ` ` ~ x_nLongLT;
					

				// DIRTY HACK END

				

/*
				// right order to draw polygon
				// .replace(`["`,``).replace(`"]`,``)
				coordinates ~= (ini["BAND1"].getKey("nLEFTEARLY_LAT") ~ ` ` ~ ini["BAND1"].getKey("nLEFTEARLY_LON"));

				coordinates ~= ini["BAND1"].getKey("nLEFTLATE_LAT") ~ ` ` ~ ini["BAND1"].getKey("nLEFTLATE_LON"); 

				coordinates ~= ini["BAND1"].getKey("nRIGHTLATE_LAT") ~ ` ` ~ ini["BAND1"].getKey("nRIGHTLATE_LON"); 

				coordinates ~= ini["BAND1"].getKey("nRIGHTEARLY_LAT") ~ ` ` ~ ini["BAND1"].getKey("nRIGHTEARLY_LON");

				// WTK require 5 points. last = first	
				coordinates ~= (ini["BAND1"].getKey("nLEFTEARLY_LAT") ~ ` ` ~ ini["BAND1"].getKey("nLEFTEARLY_LON"));
*/

				string coordinatesStr = (coordinates.join(", ")).replace(`"`,``).replace(`["`,``).replace(`"]`,``);
				
				md.coordinatesStr ~= coordinatesStr;

				// adding bounds [12.562 14.603], [9.156 9.205]
				//
						string str = coordinatesStr;
						string str1 = str.replace("POLYGON((","").replace("))","");
						auto splitted_str = str1.split(",");
						string first = splitted_str[0].replace(` `,`, `);
						string second = splitted_str[2].replace(` `,`, `);
						
						string result = (`[` ~ first ~ `],` ~ ` ` ~ `[` ~ second ~ `]`).replace(`[, `, `[`);
						md.imageBounds ~= result;
				//

				writeln(coordinatesStr);
			

				// Every RSM folder have jpg with same name
				string jpgFullName = rsmfile.replace(`.rsm`,`.jpg`);
				if(jpgFullName.exists)
				{
					md.jpgPath ~= jpgFullName.replace(`\`,`/`); // to precent escaping symbols
					jpgCount++;
				}

				else
					writeln("[ERROR] RSM folder do not have JPG file");

				mds ~= md;
			}
		}
		
		catch(Exception e)
		{
			writeln(e.msg);
		}

	}

		foreach(m;mds)
		{
			writeln(m.jpgPath);
		}

		writefln("Total RSM folders: %s. JPG added: %s", dirsWithRSMCount, jpgCount);
		DB(mds);
}

void DB(ref MyData [] mds)
{
	string[string] params;

	//version( USE_SQLITE )
	//{
	//    SQLITEDriver driver = new SQLITEDriver();
	//    string url = `D:\code\geoportal\geodata.db`; // file with DB
	//}

	//else version(USE_MYSQL)
	version(USE_MYSQL)
	{
	    // MySQL driver - you can use PostgreSQL or SQLite instead as well
	    MySQLDriver driver = new MySQLDriver();
	    string url = MySQLDriver.generateUrl("localhost", 3306, "geodb");
	    params = MySQLDriver.setUserAndPassword("root", "Infinity8");
	}

	DataSource ds = new ConnectionPoolDataSourceImpl(driver, url, params);

	// creating Connection
	auto conn = ds.getConnection();
	scope(exit) conn.close();

	// creating Statement
	auto stmt = conn.createStatement();
	scope(exit) stmt.close();

	stmt.executeUpdate("DELETE FROM rasters_previews;"); // cleanup

	foreach (md; mds)
	{
		//string sqlInsert = format("INSERT INTO rasters_previews(Path, Coordinates) VALUES('%s','%s')", md.jpgPath, md.coordinatesStr);
		string sqlInsert = format("INSERT INTO rasters_previews(Path, Coordinates, Name, imageBounds) VALUES('%s', GeomFromText('POLYGON((%s))'),'%s', '%s')", md.jpgPath, md.coordinatesStr, baseName(md.jpgPath), md.imageBounds);
		writeln(sqlInsert);
		writeln;
		try
		{
			stmt.executeUpdate(sqlInsert);
		}
		
		catch(Exception e)
		{
			writeln(e.msg);
		}
	}
	

}