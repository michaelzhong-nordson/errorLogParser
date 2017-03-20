import java.io.*;
import java.util.HashMap;
import java.util.Scanner;

class errorLogParser {
	public static void main(String[] args){
		HashMap <String, HashMap> eventType = new HashMap();
		HashMap <Sttring, HashMap> 
		JFileChooser fc = new JFileChooser();
		File input, output;
		String[] parsed_line;

		fc.showOpenDialog(null);
		input = fc.getSelectedFile();


		if(input != null){
			Scanner scan = new Scanner(input);

			while(scan.hasNextLine()){
				try{
					line = scan.nextLine().split(" ");
					System.out.println("Line Array: " + parsed_line);

					for()
				} catch(Exception e){
					System.out.println(e);
				}
			}
		}
	}
}