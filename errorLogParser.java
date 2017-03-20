import java.io.*;
import javax.swing.*;
import java.util.HashMap;
import java.util.Scanner;

//Begin Method
class errorLogParser {
	public static void main(String[] args){
		HashMap <String, HashMap> eventType = new HashMap <String, HashMap>();
		HashMap <String, HashMap> eventStage = new HashMap <String, HashMap>();
		HashMap <String, String> logmsg = new HashMap<String, String>();
		JFileChooser fc = new JFileChooser();
		File input, output;
		String[] parsed_line;

		fc.showOpenDialog(null);
		input = fc.getSelectedFile();

		try{
			Scanner scan = new Scanner(input);
			while(scan.hasNextLine()){
				parsed_line = scan.nextLine().split(" ");
				System.out.println("Line Array: " + parsed_line);

				for(i = 2; i < parsed_line.length; i++){
					// Check for unique event types
					if(!eventType.containsKey(parsed_line[i])){
						eventType.put(parsed_line[i], new)
					}
				}

			}
		}catch(Exception e){
					System.out.println(e);
		}
	}
}