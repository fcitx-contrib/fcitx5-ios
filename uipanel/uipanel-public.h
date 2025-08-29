#pragma once

#include <string>

std::string getCandidateActions(int index);
void activateCandidateAction(int index, int id);
void selectCandidate(int index);
void activateStatusAreaAction(int id);
void scroll(int start, int count);
void page(bool next);
