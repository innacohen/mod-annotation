---
date: 2025-05-15
links:
  - "[[McDougal Lab]]"
  - "[[@caiBIS686Capstone]]"
tags:
  - resource
---
date:   Thursday, May 15 2025, 7:04:46 pm


# [[2025-05-15 1904 Reading Background Information for mod-files project]]


### Background (our story)
- We can build on the [[@caiBIS686Capstone]] paper background saying that while the capstone focus was improving GPT using Chain of Thought our focus is more on improving the rule-based /traditional ML approach 
	- Rule-based methods seem to outperform GPT for recall especially for currents and receptors in [[Resources/Zotero/assets/caiBIS686Capstone/Fig 2.png| Fig 2b]]
	- Currents are 0.78 and receptors are 0.87
		- Can we compare their metrics with ours or is it a completely different model so no comparison? 
- Maybe we can frame it as "zooming into" the currents and receptors metadata types because those had the highest subtype recall 
	- Maybe our justification for focusing on traditional ML classification in addition to LLM is that precision for currents did not improve?
- Clarify that while this is not the "rule-based approach" from [[@mcdougalAutomatedMetadataSuggestion2019a]] it is kind of like an intermediate between rule-based and LLM
	- We could also introduce the three types of approaches here
		- Rule-based 
		- LLM approach
		- Classifier vs. LLM (rotation project)
			- But not sure how to specify this LLM is different than the LLM approach is different that the capstone focus since it used currents/receptors rather than all metadata


### Methods
- Specify that we ran LLM three times like [[@caiBIS686Capstone]] 
- Specify that ModelDB API was used [[@caiBIS686Capstone]]
	- But for the classifier part, for my rotation project I just used web-scraping to create the JSON file
- We also included WRITE ION in addition to USEION 
- Clarify how the classification approach is different from LLM and from rule-based
- Clarify when results are talking about type vs. subtype

### Questions on our existing methods
- What is our measure of how good something is?
	- Do we care more about recall or precision?  Are we more okay okay with FP or FN?
		- If we cared only about recall, it looks like the rule-based approach outperforms LLM at least for currents and receptors [[@caiBIS686Capstone]]
	-  Employ some of the consistency metrics from  [[Resources/Zotero/assets/caiBIS686Capstone/Table 2.png]]
	- Or perhaps use things like exact match vs. relaxed match like [[@huImprovingLargeLanguage2024]]
- Did we use the same 2-step LLM approach as [[@caiBIS686Capstone]] with comvar and headers?
- Could we use a temperature = 0 to improve randomness of LLM like [[@huImprovingLargeLanguage2024]]


### More complicated method ideas? 
- Could we use few-shot learning like [[@huImprovingLargeLanguage2024]]
- Compare against a domain-specific LLM like [[@huImprovingLargeLanguage2024]]

### Results/Figure Ideas
- Figure 1. Prompt used for GPT or just general framework  similar to [[@caiBIS686Capstone]]
- Table 1. Consort diagram or sample size of all the currents/receptor types similar to [[@caiBIS686Capstone]]
- - Table 2. Table comparing improvements in metrics for subtypes and types like [[Table 3.png]]  or [[Resources/Zotero/assets/huImprovingLargeLanguage2024/Fig 2.png]]
	- Maybe something like below?

| General Type                                  | DT    | RF    |     |
| --------------------------------------------- | ----- | ----- | --- |
| Initial                                       | 0.828 | 0.82  |     |
| +exchange<br>+nonspecific<br>+USEION multiple |       | 0.867 |     |
|                                               |       |       |     |

| Subtype                                                      | DT  | RF                                 | SVM |
| ------------------------------------------------------------ | --- | ---------------------------------- | --- |
| Initial                                                      |     | 0.56                               |     |
| Hierchical Model                                             |     | 0.819 (general) or 0.552 (overall) |     |
| combined K-Ca subtypes, A-types, "Ca+ activated feature"<br> |     | 0.629                              |     |


- Figure 2. Barplots comparing F1 like [[Resources/Zotero/assets/huImprovingLargeLanguage2024/Fig 4.png]]

- Figure 3. Barplots of frequent misclassification errors like 
[[Resources/Zotero/assets/huImprovingLargeLanguage2024/Fig 5.png]]




### Discussion
- Include some of the limitations that were mentioned by [[@caiBIS686Capstone]]
	- Incomplete metadata
	- Randomness of GPT model outputs
- Also limitations that were mentioned by [[@mcdougalIonChannelSubtype]]
	- Sample Size 
	- Ambiguous subtypes 
	- Misclassification between I Other and other subtypes
	- H-current
	- Misclassification of major classes
		-  <mark class="hltr-red">"Through looking at the misclassification samples, I found that the major confusions are between I K (A-Type) and I K (Delayed Rectifier), I Na (General) and I Na (Transient). I"</mark> [Page 2](zotero://open-pdf/library/items/RQH9RGI6?page=2&annotation=3VCKFRQ8)
		- This is kinda similar to what [[@caiBIS686Capstone]] found with misclassification of model concepts which was a major class
		-  <mark class="hltr-purple">"notable that the classification of model concepts shows the lowest overall performance among all metadata type"</mark> [Page 5](zotero://open-pdf/library/items/JQGRV34Q?page=5&annotation=KR9M445X)





## Paper-specific Questions 

### [[@mcdougalIonChannelSubtype]]
- Where does the updated code live or are some parts future directions?
- What is the difference between features vs. biological signatures? [Page 1](zotero://open-pdf/library/items/RQH9RGI6?page=1&annotation=DZ9BMKLQ)
	- <mark class="hltr-magenta">"The signature of mechanism subtypes can be identified by some features, like what ions are involved, the power of state variables in the conductance formula, and the reversal potential."</mark> [Page 1](zotero://open-pdf/library/items/RQH9RGI6?page=1&annotation=DXGPKKFC)
- What is the difference between general vs. overall accuracy? Is that type vs. subtype?
	-  <mark class="hltr-green">"The general accuracy is 0.819, and the overall accuracy is 0.552"</mark> [Page 1](zotero://open-pdf/library/items/RQH9RGI6?page=1&annotation=DMVACWSF)
- Not sure when metrics correspond to which model
	- 0.867 is that RF?

## [[@caiBIS686Capstone]]
- Was there manual annotation?
	- If so, we could try to follow the same process/protocol
- Are the GPT results we presented the same ones from this paper? 
- README file in github says only currents were looked at but I think this might be outdated?