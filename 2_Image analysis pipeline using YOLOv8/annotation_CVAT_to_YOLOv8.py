# Convert CVAT annotations to the correct YOLOv8 format for training a custom pose estimation model

import xml.etree.ElementTree as ET
import os

def normalize_coordinates(x, y, width, height):
    return x / width, y / height

def normalize_box_coordinates(xtl, ytl, xbr, ybr, width, height):
    w = xbr - xtl
    h = ybr - ytl
    center_x = xtl + (w / 2)
    center_y = ytl + (h / 2)

    normalized_x = center_x / width
    normalized_y = center_y / height
    normalized_w = w / width
    normalized_h = h / height

    return normalized_x, normalized_y, normalized_w, normalized_h


def parse_xml(xml_file):
    tree = ET.parse(xml_file)
    root = tree.getroot()

    label_mapping = {'jackdaw': 0}  # Adjust as needed

    data = {}

    for image_elem in root.findall('image'):
        image_name = image_elem.get('name')
        width = float(image_elem.get('width'))
        height = float(image_elem.get('height'))

        if image_name not in data:
            data[image_name] = []

        boxes = image_elem.findall('box')
        points_list = image_elem.findall('points')

        for i, box_elem in enumerate(boxes):
            box_label_str = box_elem.get('label')
            box_label = label_mapping.get(box_label_str, -1)  # Default to -1 if label is not found
            xtl = float(box_elem.get('xtl'))
            ytl = float(box_elem.get('ytl'))
            xbr = float(box_elem.get('xbr'))
            ybr = float(box_elem.get('ybr'))

            normalized_box = normalize_box_coordinates(xtl, ytl, xbr, ybr, width, height)

            if i < len(points_list):
                points_elem = points_list[i]
                points_str = points_elem.get('points')
                coords = [round(float(coord), 6) for coord in points_str.replace(',', ';').split(';')]
                normalized_points = []
                for i in range(0, len(coords), 2):
                    x, y = coords[i], coords[i + 1]
                    normalized_x, normalized_y = round(x / width, 6), round(y / height, 6)
                    visibility = 0 if normalized_x < 0.1 and normalized_y < 0.1 else 1
                    normalized_points.extend([normalized_x, normalized_y, int(visibility)])
            else:
                normalized_points = []

            data[image_name].append({
                'box_label': box_label,
                'normalized_box': normalized_box,
                'normalized_points': normalized_points
            })

    return data

def write_txt_files(data, output_folder):
    if not os.path.exists(output_folder):
        os.mkdir(output_folder)
    for image_name, items in data.items():
        output_file = os.path.join(output_folder, f"{image_name[:-4]}.txt")
        with open(output_file, 'w') as file:
            for item in items:
                visibility_coords = [int(coord) if i % 3 == 2 else coord for i, coord in
                                     enumerate(item['normalized_points'])]
                line = ' '.join([str(item['box_label'])] + [f'{coord:.6f}' for coord in item['normalized_box']] +
                                [str(coord) for coord in visibility_coords])
                file.write(f'{line}\n')

if __name__ == "__main__":

    xml_file = "your_annotations_file.xml"  # Replace with the path to your XML files

    output_folder = "your_annotation_output_folder" # Replace with the path to your directory where .txt files should be saved


    data = parse_xml(xml_file)
    write_txt_files(data, output_folder)
