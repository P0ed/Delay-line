#pragma once

#import <Accelerate/Accelerate.h>

struct Buffer {
	float *data;
	int length;
	int offset;

	Buffer(float *data = nullptr, int length = 0, int offset = 0) {
		this->data = data;
		this->length = length;
		this->offset = offset;
	}

	void allocate(int len) {
		data = len ? new float[len] : nullptr;
		length = len;
		offset = 0;
	}
	void deallocate() {
		delete[] data;
		data = nullptr;
		length = 0;
		offset = 0;
	}

	float & operator[](int index) { return data[(offset + index) % length]; }

	void move(int dx) {
		offset = (offset + dx) % length;
	}
	void read(float *data, int length) {
		for (int i = 0; i < length; ++i) data[i] = (*this)[i];
	}
	void write(const float *data, int length) {
		for (int i = 0; i < length; ++i) (*this)[i] = data[i];
	}
};
