import java.io.*;
import javax.swing.*;
import java.util.HashMap;
import java.util.Scanner;
import java.util.ArrayList;
import java.util.List;

//Begin Method
class errorLogParser {
	public static void main(String[] args){
		HashMap <String, HashMap> logType = new HashMap <String, HashMap>();
		HashMap <String, List<String>> logStage_buff = new HashMap <String, List<String>>();
		List<String> logMsg_buff = new ArrayList<String>();
		JFileChooser fc = new JFileChooser();
		File input, output;
		ArrayList<String> parsed_line = new ArrayList<String>(5);

		try{
			fc.showOpenDialog(null);
			input = fc.getSelectedFile();
			Scanner scan = new Scanner(input);
			Scanner scan2;
			while(scan.hasNextLine()){
				String logMsg_Str = "";

				String temp = scan.nextLine().toString();
				System.out.println("Working with Line: " + temp);
				scan2 = new Scanner(temp);

				int i = 0;

				while(scan2.hasNext() && i < 4){
					parsed_line.add(i, scan2.next());
					System.out.println("Adding word " + parsed_line.get(i));
					i++;
				}


				while(scan2.hasNext()){
					logMsg_Str += scan2.next().toString() + " ";
					System.out.println("new String: " + logMsg_Str);
					parsed_line.add(4, logMsg_Str);
				}

				scan2.close();

				System.out.println(parsed_line.get(0) + " " + parsed_line.get(1) + " " +parsed_line.get(2) + " " + 
					parsed_line.get(3) + " " +parsed_line.get(4));

				// Check for unique event types
				if (!logType.containsKey(parsed_line.get(2))){
					logType = newType(logType, parsed_line);
				}
				
				else{
					logStage_buff = logType.get(parsed_line.get(2));

					if(!logStage_buff.containsKey(parsed_line.get(3))){
						logStage_buff = newLocation(parsed_line);
						logType.put(parsed_line.get(2), logStage_buff);
					}

					else{
						logMsg_buff = logStage_buff.get(parsed_line.get(3));

						if(!logMsg_buff.contains(parsed_line.get(4))){
							logMsg_buff = newMsg(logMsg_buff, parsed_line.get(4));
							logStage_buff.put(parsed_line.get(3), logMsg_buff);
							logType.put(parsed_line.get(2), logStage_buff);
						}
					}
				}
			}
		}catch(Exception e){
			e.printStackTrace(System.out);
		}

	}

	private static HashMap<String, HashMap> newType(HashMap<String, HashMap> typeMap, ArrayList<String> data){
		HashMap<String, List<String>> locations = newLocation(data);
		typeMap.put(data.get(2), locations);

		return typeMap;

	}

	private static HashMap<String, List<String>> newLocation(ArrayList<String> data){
		List<String> list = new ArrayList<String>();
		HashMap<String, List<String>> loc_hashMap = new HashMap<String, List<String>> ();
		list = newMsg(list, data.get(4));
		loc_hashMap.put(data.get(3), list);

		return loc_hashMap;
	}

	private static List<String> newMsg(List<String> l, String data){
		if(!l.contains(data))
			l.add(data);
		else
			System.err.println("Msg already exists in List");
		return l;
	}
}