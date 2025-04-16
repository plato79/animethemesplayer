#!/usr/bin/env python3
import requests
import json
from datetime import datetime

def test_anime_api():
    """
    Test the AnimeThemes API and save the response for analysis
    """
    # API URL with query parameters
    url = "https://api.animethemes.moe/anime"
    params = {
        "q": "Naruto",
        "fields[anime]": "id,name,media_format",
        "include": "images,animethemes.animethemeentries.videos.audio"
    }
    
    # Make the request
    print(f"Making request to {url}...")
    response = requests.get(url, params=params)
    
    # Check if request was successful
    if response.status_code == 200:
        data = response.json()
        
        # Save the full response to a JSON file for detailed analysis
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        filename = f"anime_api_response_{timestamp}.json"
        with open(filename, "w") as f:
            json.dump(data, f, indent=2)
        print(f"Full response saved to {filename}")
        
        # Print summary of the response
        if "anime" in data:
            anime_count = len(data["anime"])
            print(f"Found {anime_count} anime entries")
            
            # Print basic info for the first anime
            if anime_count > 0:
                first_anime = data["anime"][0]
                print("\nFirst anime details:")
                print(f"ID: {first_anime.get('id')}")
                print(f"Name: {first_anime.get('name')}")
                print(f"Media Format: {first_anime.get('media_format')}")
                
                # Check for images
                if "images" in first_anime and first_anime["images"]:
                    print(f"Has {len(first_anime['images'])} images")
                    for i, img in enumerate(first_anime["images"]):
                        print(f"  Image {i+1}: {img.get('link', 'No link')}")
                
                # Check for themes
                if "animethemes" in first_anime and first_anime["animethemes"]:
                    themes_count = len(first_anime["animethemes"])
                    print(f"Has {themes_count} themes")
                    
                    # Analyze first theme
                    if themes_count > 0:
                        first_theme = first_anime["animethemes"][0]
                        print(f"\nFirst theme: {first_theme.get('name', 'Unknown')}")
                        
                        # Check for entries
                        if "animethemeentries" in first_theme and first_theme["animethemeentries"]:
                            entries_count = len(first_theme["animethemeentries"])
                            print(f"  Has {entries_count} entries")
                            
                            # Analyze first entry
                            if entries_count > 0:
                                first_entry = first_theme["animethemeentries"][0]
                                print(f"  First entry: {first_entry.get('version', 'Main')}")
                                
                                # Check for videos
                                if "videos" in first_entry and first_entry["videos"]:
                                    videos_count = len(first_entry["videos"])
                                    print(f"    Has {videos_count} videos")
                                    
                                    # Analyze first video
                                    if videos_count > 0:
                                        first_video = first_entry["videos"][0]
                                        print(f"    First video: {first_video.get('link', 'No link')}")
                                        
                                        # Check for audio
                                        if "audio" in first_video and first_video["audio"]:
                                            audio = first_video["audio"]
                                            print(f"      Has audio: {audio.get('link', 'No link')}")
                
        else:
            print("No anime entries found in the response")
    else:
        print(f"Request failed with status code: {response.status_code}")
        print(response.text)

if __name__ == "__main__":
    test_anime_api()