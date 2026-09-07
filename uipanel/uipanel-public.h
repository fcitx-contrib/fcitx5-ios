#pragma once

#include <string>

std::string getCandidateActions(int index);
void activateCandidateAction(int index, int id);
void activateCandidateTabAction(int id);
void selectCandidate(int index);
void activateStatusAreaAction(int id);
void scroll(const char *program, const char *documentIdentifier, int start,
            int count);
void page(bool next);
